import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ftp_server/file_operations/physical_file_operations.dart';
import 'package:ftp_server/ftp_server.dart';
import 'package:ftp_server/server_type.dart';
import 'package:image_picker/image_picker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:external_path/external_path.dart';

const Color kLightColor = Color(0xFFF7F7FF);
const Color kDarkColor = Color(0xFF27187E);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FTPShare',
      theme: ThemeData(
        scaffoldBackgroundColor: kLightColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kDarkColor,
          primary: kDarkColor,
          surface: kLightColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kDarkColor,
          foregroundColor: kLightColor,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _portController = TextEditingController(text: '1111');
  final TextEditingController _passwordController = TextEditingController();
  final NetworkInfo _networkInfo = NetworkInfo();

  FtpServer? _server;
  bool _isStarting = false;
  String _status = 'Служба остановлена';
  String _connectionText = '';
  Directory? _sharedDir;
  final List<SelectedFile?> _selectedRows = [null];

  bool get _isRunning => _server != null;

  @override
  void initState() {
    super.initState();
    _prepareSharedDir();
  }

  Future<void> _prepareSharedDir() async {
  Directory dir;
  
  if (Platform.isAndroid) {
    try {
      // Получаем реальный путь к общедоступной папке Downloads
      final downloadsPath = await ExternalPath.getExternalStoragePublicDirectory('Download');
      dir = Directory(p.join(downloadsPath, 'FTPShare'));
    } catch (e) {
      // Fallback: используем изолированную папку приложения
      final appDir = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(appDir.path, 'FTPShare'));
    }
  } else {
    // iOS: используем Documents или Downloads
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      dir = Directory(p.join(downloadsDir.path, 'FTPShare'));
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(appDir.path, 'FTPShare'));
    }
  }
  
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  
  setState(() {
    _sharedDir = dir;
  });
}
  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.photos.request();
    await Permission.videos.request();
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
    }
  }
  Future<void> _openSharedDirectory() async {
  final dir = _sharedDir;
  if (dir == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Папка ещё не создана')),
    );
    return;
  }

  // Пытаемся открыть папку через системный файловый менеджер
  try {
    final result = await OpenFile.open(dir.path);
    if (result.type != ResultType.done) {
      // Если открыть не удалось (нет подходящего приложения или ошибка),
      // показываем диалог с путём и возможностью скопировать
      _showPathDialog(dir.path);
    }
  } catch (e) {
    _showPathDialog(dir.path);
  }
}

void _showPathDialog(String path) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Путь к папке FTP'),
      content: SelectableText(path),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Закрыть'),
        ),
        TextButton(
          onPressed: () {
            // Копируем путь в буфер обмена
            Clipboard.setData(ClipboardData(text: path));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Путь скопирован')),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Копировать путь'),
        ),
      ],
    ),
  );
}

  Future<void> _toggleServer() async {
    if (_isStarting) return;
    setState(() {
      _isStarting = true;
    });

    try {
      if (_isRunning) {
        await _server!.stop();
        setState(() {
          _server = null;
          _status = 'Служба остановлена';
          _connectionText = '';
          _selectedRows
            ..clear()
            ..add(null);
        });
      } else {
        await _requestPermissions();
        await _prepareSharedDir();
        final dir = _sharedDir;
        if (dir == null) {
          throw Exception('Не удалось подготовить папку FTPShare');
        }

        final parsedPort = int.tryParse(_portController.text.trim()) ?? 1111;
        final password = _passwordController.text.trim();

        final ftp = FtpServer(
          parsedPort,
          fileOperations: PhysicalFileOperations(dir.path),
          serverType: ServerType.readAndWrite,
          password: password.isEmpty ? null : password,
          username: null,
        );

        await ftp.startInBackground();
        final ip = await _networkInfo.getWifiIP() ?? 'IP не найден';
        setState(() {
          _server = ftp;
          _status = 'Служба запущена';
          _connectionText = 'ftp://$ip:${ftp.port}\nВход: анонимный';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _openSettingsMenu() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Настройки FTP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Порт',
                  hintText: '1111',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  hintText: 'По умолчанию нет',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goToFilePickerPage() async {
    if (_sharedDir == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FileSharePage(
          sharedDir: _sharedDir!,
          rows: _selectedRows,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _portController.dispose();
    _passwordController.dispose();
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _openSettingsMenu,
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Запустить службу',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kDarkColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _toggleServer,
                child: Text(_isRunning ? 'Остановить службу' : 'Пуск'),
              ),
            ),
            if (_isRunning) ...[
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: _goToFilePickerPage,
      child: const Text('Выбрать файлы'),
    ),
  ),
  const SizedBox(height: 8),  // небольшой отступ
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _openSharedDirectory,
      icon: const Icon(Icons.folder_open),
      label: const Text('Открыть папку FTP'),
    ),
  ),
],
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kDarkColor),
            ),
            if (_connectionText.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                _connectionText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kDarkColor),
              ),
              const SizedBox(height: 8),
              if (_sharedDir != null)
                Text(
                  'Папка для FTP: ${_sharedDir!.path}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kDarkColor),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class FileSharePage extends StatefulWidget {
  const FileSharePage({
    super.key,
    required this.sharedDir,
    required this.rows,
  });

  final Directory sharedDir;
  final List<SelectedFile?> rows;

  @override
  State<FileSharePage> createState() => _FileSharePageState();
}

class _FileSharePageState extends State<FileSharePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _chooseFileForRow(int index) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Галерея (фото)'),
                onTap: () => Navigator.of(context).pop('image'),
              ),
              ListTile(
                title: const Text('Галерея (видео)'),
                onTap: () => Navigator.of(context).pop('video'),
              ),
              ListTile(
                title: const Text('Файлы/папки'),
                onTap: () => Navigator.of(context).pop('file'),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    String? path;
    if (source == 'image') {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      path = image?.path;
    } else if (source == 'video') {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      path = video?.path;
    } else {
      final result = await FilePicker.pickFiles(allowMultiple: false);
      path = result?.files.single.path;
    }

    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;

    final length = await file.length();
    final selected = SelectedFile(
      path: path,
      name: p.basename(path),
      sizeBytes: length,
    );

    setState(() {
      widget.rows[index] = selected;
      final hasEmptyRow = widget.rows.any((row) => row == null);
      if (!hasEmptyRow) {
        widget.rows.add(null);
      }
    });
  }

  void _removeRowFile(int index) {
    setState(() {
      widget.rows[index] = null;
    });
  }

  void _clearRows() {
    setState(() {
      widget.rows
        ..clear()
        ..add(null);
    });
  }

  Future<void> _sendFiles() async {
    final selected = widget.rows.whereType<SelectedFile>().toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите файлы')),
      );
      return;
    }

    for (final file in selected) {
      final source = File(file.path);
      if (source.existsSync()) {
        final target = File(p.join(widget.sharedDir.path, file.name));
        await source.copy(target.path);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файлы готовы для загрузки по FTP')),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Выбранные файлы')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                },
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: Color(0xFFEFEFEF)),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Название'),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Вес'),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Действие'),
                      ),
                    ],
                  ),
                  ...List.generate(widget.rows.length, (index) {
                    final file = widget.rows[index];
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(file?.name ?? 'Пусто'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(file == null ? '-' : _formatSize(file.sizeBytes)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: file == null
                              ? ElevatedButton(
                                  onPressed: () => _chooseFileForRow(index),
                                  child: const Text('+ Выбрать'),
                                )
                              : ElevatedButton(
                                  onPressed: () => _removeRowFile(index),
                                  child: const Text('X'),
                                ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPadding),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _clearRows,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Очистить список'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendFiles,
                      child: const Text('Отправить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectedFile {
  SelectedFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}
