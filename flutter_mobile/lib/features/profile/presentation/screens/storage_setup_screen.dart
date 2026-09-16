import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/storage/s3_storage_provider.dart';
import 'package:flutter_mobile/core/storage/storage_provider.dart';
import 'package:flutter_mobile/core/storage/storage_settings_service.dart';
import 'package:flutter_mobile/core/storage/webdav_storage_provider.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';

class StorageSetupScreen extends ConsumerStatefulWidget {
  const StorageSetupScreen({super.key});

  @override
  ConsumerState<StorageSetupScreen> createState() => _StorageSetupScreenState();
}

class _StorageSetupScreenState extends ConsumerState<StorageSetupScreen> {
  final _service = const StorageSettingsService();
  StorageProviderType _selectedType = StorageProviderType.local;
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testStatus;
  bool? _testSuccess;

  final _s3EndpointController = TextEditingController();
  final _s3BucketController = TextEditingController();
  final _s3AccessKeyController = TextEditingController();
  final _s3SecretKeyController = TextEditingController();
  final _s3RegionController = TextEditingController(text: 'us-east-1');

  final _webdavUrlController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPassController = TextEditingController();
  final _webdavBasePathController = TextEditingController(text: '/kioku');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _s3EndpointController.dispose();
    _s3BucketController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3RegionController.dispose();

    _webdavUrlController.dispose();
    _webdavUserController.dispose();
    _webdavPassController.dispose();
    _webdavBasePathController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final type = await _service.getActiveProviderType();
    final s3Config = await _service.getS3Config();
    final webdavConfig = await _service.getWebDavConfig();

    if (s3Config != null) {
      _s3EndpointController.text = s3Config.endpoint;
      _s3BucketController.text = s3Config.bucket;
      _s3AccessKeyController.text = s3Config.accessKeyId;
      _s3SecretKeyController.text = s3Config.secretAccessKey;
      _s3RegionController.text = s3Config.region;
    }

    if (webdavConfig != null) {
      _webdavUrlController.text = webdavConfig.serverUrl;
      _webdavUserController.text = webdavConfig.username;
      _webdavPassController.text = webdavConfig.password;
      _webdavBasePathController.text = webdavConfig.basePath;
    }

    if (mounted) {
      setState(() {
        _selectedType = type;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndApply() async {
    if (_selectedType == StorageProviderType.s3) {
      final s3 = S3StorageConfig(
        endpoint: _s3EndpointController.text.trim(),
        bucket: _s3BucketController.text.trim(),
        accessKeyId: _s3AccessKeyController.text.trim(),
        secretAccessKey: _s3SecretKeyController.text.trim(),
        region: _s3RegionController.text.trim().isEmpty ? 'us-east-1' : _s3RegionController.text.trim(),
      );
      await _service.saveS3Config(s3);
    } else if (_selectedType == StorageProviderType.webdav) {
      final dav = WebDavConfig(
        serverUrl: _webdavUrlController.text.trim(),
        username: _webdavUserController.text.trim(),
        password: _webdavPassController.text.trim(),
        basePath: _webdavBasePathController.text.trim().isEmpty ? '/kioku' : _webdavBasePathController.text.trim(),
      );
      await _service.saveWebDavConfig(dav);
    }

    await _service.setActiveProviderType(_selectedType);
    ref.read(activeStorageTypeProvider.notifier).state = _selectedType;
    ref.invalidate(storageProviderProvider);
    ref.invalidate(memoriesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage provider updated to ${_selectedType.name.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testStatus = 'Connecting...';
      _testSuccess = null;
    });

    try {
      if (_selectedType == StorageProviderType.s3) {
        final config = S3StorageConfig(
          endpoint: _s3EndpointController.text.trim(),
          bucket: _s3BucketController.text.trim(),
          accessKeyId: _s3AccessKeyController.text.trim(),
          secretAccessKey: _s3SecretKeyController.text.trim(),
          region: _s3RegionController.text.trim().isEmpty ? 'us-east-1' : _s3RegionController.text.trim(),
        );
        final provider = S3StorageProvider(config: config);
        await provider.listBlobs('');
        setState(() {
          _testStatus = 'Connection successful! Bucket is accessible.';
          _testSuccess = true;
        });
      } else if (_selectedType == StorageProviderType.webdav) {
        final config = WebDavConfig(
          serverUrl: _webdavUrlController.text.trim(),
          username: _webdavUserController.text.trim(),
          password: _webdavPassController.text.trim(),
          basePath: _webdavBasePathController.text.trim().isEmpty ? '/kioku' : _webdavBasePathController.text.trim(),
        );
        final provider = WebDavStorageProvider(config: config);
        await provider.listBlobs('');
        setState(() {
          _testStatus = 'Connection successful! WebDAV directory is ready.';
          _testSuccess = true;
        });
      } else {
        setState(() {
          _testStatus = '${_selectedType.name.toUpperCase()} is active and operational.';
          _testSuccess = true;
        });
      }
    } catch (e) {
      setState(() {
        _testStatus = 'Connection failed: $e';
        _testSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Storage Setup'), backgroundColor: colors.background),
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Storage Backend',
          style: typography.headlineSmall?.copyWith(fontSize: 20, color: colors.ink),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose where your encrypted blobs are preserved. Kioku operates as a zero-knowledge system: all media and metadata are encrypted client-side before touching any backend.',
                style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
              const Gap(16),

              _buildTypeSelector(colors, typography),
              const Gap(20),

              if (_selectedType == StorageProviderType.s3)
                _buildS3Form(colors, typography)
              else if (_selectedType == StorageProviderType.webdav)
                _buildWebDavForm(colors, typography)
              else if (_selectedType == StorageProviderType.mesh)
                _buildMeshInfo(colors, typography)
              else if (_selectedType == StorageProviderType.drive)
                _buildDriveInfo(colors, typography)
              else
                _buildLocalInfo(colors, typography),

              const Gap(20),

              if (_selectedType == StorageProviderType.s3 || _selectedType == StorageProviderType.webdav) ...[
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                      : Icon(Icons.network_check_outlined, size: 18, color: colors.primary),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection', style: TextStyle(color: colors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_testStatus != null) ...[
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testSuccess == true ? colors.accentSoft : colors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testSuccess == true ? colors.primaryDark : colors.danger,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testSuccess == true ? Icons.check_circle_outline : Icons.error_outline,
                          size: 18,
                          color: _testSuccess == true ? colors.primaryDark : colors.danger,
                        ),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            _testStatus!,
                            style: typography.bodySmall?.copyWith(
                              color: _testSuccess == true ? colors.primaryDark : colors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Gap(20),
              ],

              ClayButton(
                label: 'Save & Switch Backend',
                variant: ClayButtonVariant.primary,
                onPressed: _saveAndApply,
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(AppColors colors, TextTheme typography) {
    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          RadioListTile<StorageProviderType>(
            title: const Text('Local Storage'),
            subtitle: const Text('Stored offline on this device'),
            value: StorageProviderType.local,
            groupValue: _selectedType,
            activeColor: colors.primary,
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          RadioListTile<StorageProviderType>(
            title: const Text('Google Drive'),
            subtitle: const Text('Sync encrypted blobs to personal Drive folder'),
            value: StorageProviderType.drive,
            groupValue: _selectedType,
            activeColor: colors.primary,
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          RadioListTile<StorageProviderType>(
            title: const Text('S3-Compatible Cloud (BYOS)'),
            subtitle: const Text('AWS S3, Cloudflare R2, Backblaze B2, MinIO'),
            value: StorageProviderType.s3,
            groupValue: _selectedType,
            activeColor: colors.primary,
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          RadioListTile<StorageProviderType>(
            title: const Text('WebDAV Storage'),
            subtitle: const Text('Nextcloud, ownCloud, or custom WebDAV server'),
            value: StorageProviderType.webdav,
            groupValue: _selectedType,
            activeColor: colors.primary,
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          RadioListTile<StorageProviderType>(
            title: const Text('P2P Mesh (Decentralized)'),
            subtitle: const Text('Replicate blobs directly between devices via WebRTC'),
            value: StorageProviderType.mesh,
            groupValue: _selectedType,
            activeColor: colors.primary,
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildS3Form(AppColors colors, TextTheme typography) {
    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('S3 Configuration', style: typography.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.ink)),
          const Gap(12),
          TextField(
            controller: _s3EndpointController,
            decoration: const InputDecoration(labelText: 'Endpoint URL (e.g. https://s3.amazonaws.com)'),
          ),
          const Gap(10),
          TextField(
            controller: _s3BucketController,
            decoration: const InputDecoration(labelText: 'Bucket Name'),
          ),
          const Gap(10),
          TextField(
            controller: _s3AccessKeyController,
            decoration: const InputDecoration(labelText: 'Access Key ID'),
          ),
          const Gap(10),
          TextField(
            controller: _s3SecretKeyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Secret Access Key'),
          ),
          const Gap(10),
          TextField(
            controller: _s3RegionController,
            decoration: const InputDecoration(labelText: 'Region (e.g. us-east-1)'),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDavForm(AppColors colors, TextTheme typography) {
    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WebDAV Configuration', style: typography.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.ink)),
          const Gap(12),
          TextField(
            controller: _webdavUrlController,
            decoration: const InputDecoration(labelText: 'Server URL (e.g. https://nextcloud.example.com)'),
          ),
          const Gap(10),
          TextField(
            controller: _webdavUserController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const Gap(10),
          TextField(
            controller: _webdavPassController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password / App Token'),
          ),
          const Gap(10),
          TextField(
            controller: _webdavBasePathController,
            decoration: const InputDecoration(labelText: 'Base Path (default: /kioku)'),
          ),
        ],
      ),
    );
  }

  Widget _buildMeshInfo(AppColors colors, TextTheme typography) {
    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, color: colors.primary),
              const Gap(8),
              Text('P2P Mesh Network', style: typography.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.ink)),
            ],
          ),
          const Gap(8),
          Text(
            'Devices in an album replicate encrypted chunks directly with one another over WebRTC data channels. The companion backend acts strictly as a lightweight signaling relay without ever handling decryption keys or raw photos.',
            style: typography.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveInfo(AppColors colors, TextTheme typography) {
    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, color: colors.primary),
              const Gap(8),
              Text('Google Drive Vault', style: typography.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.ink)),
            ],
          ),
          const Gap(8),
          Text(
            'Encrypted .enc files are synced into your own "Kioku" folder on Google Drive. Google servers see only high-entropy ciphertext and cannot read captions, dates, or image contents.',
            style: typography.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalInfo(AppColors colors, TextTheme typography) {
    return ClayCard(
      variant: ClayVariant.elevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android_outlined, color: colors.primary),
              const Gap(8),
              Text('Local Device Storage', style: typography.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.ink)),
            ],
          ),
          const Gap(8),
          Text(
            'Encrypted blobs are saved directly to this device’s isolated app storage sandbox. 100% offline, zero network egress.',
            style: typography.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
