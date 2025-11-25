#!/usr/bin/env node

/**
 * Remote Storage Sync Script for Embedded Hive Database
 * This script syncs local embedded Hive database with remote storage
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const CONFIG = {
  storageType: process.env.HIVE_STORAGE_TYPE || 'disk',
  localPath: process.env.BLADE_STATE_DIR || './.blade/state',
  backupDir: process.env.BACKUP_DIR || './backups',
  encryptionKey: process.env.ENCRYPTION_KEY || crypto.randomBytes(32).toString('hex'),
  s3: {
    bucket: process.env.HIVE_S3_BUCKET,
    region: process.env.AWS_REGION || 'us-east-1',
    prefix: process.env.HIVE_S3_PREFIX || 'hive-databases/main'
  },
  remote: {
    endpoint: process.env.REMOTE_STORAGE_ENDPOINT,
    apiKey: process.env.REMOTE_STORAGE_API_KEY
  }
};

// Colors for output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Encryption utilities
function encrypt(data, key) {
  const algorithm = 'aes-256-gcm';
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipher(algorithm, key);
  cipher.setAAD(Buffer.from('hive-database', 'utf8'));
  
  const encrypted = Buffer.concat([
    cipher.update(data, 'utf8'),
    cipher.final()
  ]);
  
  const authTag = cipher.getAuthTag();
  
  return {
    encrypted: encrypted.toString('base64'),
    iv: iv.toString('base64'),
    authTag: authTag.toString('base64')
  };
}

function decrypt(encryptedData, key) {
  const algorithm = 'aes-256-gcm';
  const decipher = crypto.createDecipher(algorithm, key);
  decipher.setAAD(Buffer.from('hive-database', 'utf8'));
  decipher.setAuthTag(Buffer.from(encryptedData.authTag, 'base64'));
  
  const decrypted = Buffer.concat([
    decipher.update(encryptedData.encrypted, 'base64'),
    decipher.final()
  ]);
  
  return decrypted.toString('utf8');
}

// S3 Storage implementation
class S3StorageManager {
  constructor(config) {
    this.config = config;
    this.client = null;
  }

  async initialize() {
    try {
      // Try to import AWS SDK
      const { S3Client, PutObjectCommand, GetObjectCommand } = await import('@aws-sdk/client-s3');
      
      this.client = new S3Client({
        region: this.config.region,
        credentials: {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
        }
      });
      
      this.PutObjectCommand = PutObjectCommand;
      this.GetObjectCommand = GetObjectCommand;
      
      log('✅ S3 client initialized', 'green');
      return true;
    } catch (error) {
      log(`❌ Failed to initialize S3: ${error.message}`, 'red');
      return false;
    }
  }

  async upload(key, data, encrypt = true) {
    if (!this.client) {
      throw new Error('S3 client not initialized');
    }

    try {
      let uploadData = data;
      let metadata = {
        ContentType: 'application/octet-stream',
        StorageClass: 'STANDARD_IA', // Cost-optimized
        Metadata: {
          'original-size': data.length.toString(),
          'storage-type': 'hive-database',
          'sync-timestamp': new Date().toISOString()
        }
      };

      if (encrypt) {
        const encrypted = encrypt(data, CONFIG.encryptionKey);
        uploadData = JSON.stringify(encrypted);
        metadata.Metadata['encrypted'] = 'true';
        metadata.Metadata['encryption-algorithm'] = 'aes-256-gcm';
      }

      const command = new this.PutObjectCommand({
        Bucket: this.config.bucket,
        Key: `${this.config.prefix}/${key}`,
        Body: uploadData,
        ...metadata
      });

      const result = await this.client.send(command);
      log(`📤 Uploaded to S3: ${key} (${data.length} bytes)`, 'green');
      return result;
    } catch (error) {
      log(`❌ S3 upload failed: ${error.message}`, 'red');
      throw error;
    }
  }

  async download(key, decrypt = true) {
    if (!this.client) {
      throw new Error('S3 client not initialized');
    }

    try {
      const command = new this.GetObjectCommand({
        Bucket: this.config.bucket,
        Key: `${this.config.prefix}/${key}`
      });

      const result = await this.client.send(command);
      const data = await result.Body.transformToString();

      if (decrypt && result.Metadata?.encrypted === 'true') {
        const encrypted = JSON.parse(data);
        return decrypt(encrypted, CONFIG.encryptionKey);
      }

      return data;
    } catch (error) {
      if (error.name === 'NoSuchKey') {
        log(`📭 File not found in S3: ${key}`, 'yellow');
        return null;
      }
      log(`❌ S3 download failed: ${error.message}`, 'red');
      throw error;
    }
  }
}

// Remote API Storage implementation
class RemoteAPIStorageManager {
  constructor(config) {
    this.config = config;
  }

  async upload(key, data, encrypt = true) {
    try {
      let uploadData = data;
      
      if (encrypt) {
        const encrypted = encrypt(data, CONFIG.encryptionKey);
        uploadData = JSON.stringify(encrypted);
      }

      const response = await fetch(`${this.config.endpoint}/${key}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/octet-stream',
          'Authorization': `Bearer ${this.config.apiKey}`,
          'X-Storage-Type': 'hive-database',
          'X-Encrypted': encrypt.toString(),
          'X-Timestamp': new Date().toISOString()
        },
        body: uploadData
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      log(`📤 Uploaded to remote API: ${key} (${data.length} bytes)`, 'green');
      return await response.json();
    } catch (error) {
      log(`❌ Remote API upload failed: ${error.message}`, 'red');
      throw error;
    }
  }

  async download(key, decrypt = true) {
    try {
      const response = await fetch(`${this.config.endpoint}/${key}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.config.apiKey}`
        }
      });

      if (response.status === 404) {
        log(`📭 File not found in remote API: ${key}`, 'yellow');
        return null;
      }

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.text();
      const encrypted = response.headers.get('X-Encrypted') === 'true';

      if (decrypt && encrypted) {
        const encryptedData = JSON.parse(data);
        return decrypt(encryptedData, CONFIG.encryptionKey);
      }

      return data;
    } catch (error) {
      log(`❌ Remote API download failed: ${error.message}`, 'red');
      throw error;
    }
  }
}

// Main sync functionality
class DatabaseSyncer {
  constructor() {
    this.storageManager = null;
    this.dbPath = path.join(CONFIG.localPath, 'databases/main/db.sqlite');
  }

  async initialize() {
    log('🔧 Initializing database syncer...', 'blue');

    // Create storage manager based on configuration
    switch (CONFIG.storageType) {
      case 's3':
        this.storageManager = new S3StorageManager(CONFIG.s3);
        break;
      case 'remote':
        this.storageManager = new RemoteAPIStorageManager(CONFIG.remote);
        break;
      case 'disk':
        log('🏠 Local disk storage detected - no remote sync needed', 'yellow');
        log('💡 Set HIVE_STORAGE_TYPE=s3 or HIVE_STORAGE_TYPE=remote for remote storage', 'cyan');
        return false;
      default:
        log('❌ Unsupported storage type. Use: disk, s3, or remote', 'red');
        return false;
    }

    // Initialize storage manager
    const initialized = await this.storageManager.initialize();
    if (!initialized) {
      return false;
    }

    // Check if local database exists
    if (!fs.existsSync(this.dbPath)) {
      log('⚠️  Local database not found. Run your app first to create it.', 'yellow');
      return false;
    }

    return true;
  }

  async uploadDatabase() {
    try {
      log('📤 Uploading database to remote storage...', 'blue');
      
      // Read local database
      const dbData = fs.readFileSync(this.dbPath);
      
      // Create backup info
      const backupInfo = {
        timestamp: new Date().toISOString(),
        size: dbData.length,
        checksum: crypto.createHash('sha256').update(dbData).digest('hex'),
        version: '1.0'
      };

      // Upload database file
      await this.storageManager.upload('db.sqlite', dbData);
      
      // Upload metadata
      await this.storageManager.upload('metadata.json', JSON.stringify(backupInfo, null, 2));
      
      log('✅ Database uploaded successfully!', 'green');
      return true;
    } catch (error) {
      log(`❌ Upload failed: ${error.message}`, 'red');
      return false;
    }
  }

  async downloadDatabase() {
    try {
      log('📥 Downloading database from remote storage...', 'blue');
      
      // Download metadata first
      const metadataData = await this.storageManager.download('metadata.json');
      if (!metadataData) {
        log('📭 No remote database found', 'yellow');
        return false;
      }

      const metadata = JSON.parse(metadataData);
      log(`📋 Remote database info: ${new Date(metadata.timestamp).toLocaleString()}`, 'cyan');
      
      // Download database file
      const dbData = await this.storageManager.download('db.sqlite');
      if (!dbData) {
        log('❌ Database file not found in remote storage', 'red');
        return false;
      }

      // Verify checksum
      const checksum = crypto.createHash('sha256').update(dbData).digest('hex');
      if (checksum !== metadata.checksum) {
        log('❌ Checksum mismatch! Data may be corrupted.', 'red');
        return false;
      }

      // Create backup of current local database
      if (fs.existsSync(this.dbPath)) {
        const backupPath = path.join(CONFIG.backupDir, `db-backup-${Date.now()}.sqlite`);
        fs.mkdirSync(CONFIG.backupDir, { recursive: true });
        fs.copyFileSync(this.dbPath, backupPath);
        log(`💾 Local backup created: ${backupPath}`, 'green');
      }

      // Write downloaded database
      fs.writeFileSync(this.dbPath, dbData);
      
      log('✅ Database downloaded and restored successfully!', 'green');
      return true;
    } catch (error) {
      log(`❌ Download failed: ${error.message}`, 'red');
      return false;
    }
  }

  async syncStatus() {
    try {
      log('📊 Checking sync status...', 'blue');
      
      const localStats = fs.existsSync(this.dbPath) ? 
        fs.statSync(this.dbPath) : null;
      
      const metadataData = await this.storageManager.download('metadata.json');
      const remoteMetadata = metadataData ? JSON.parse(metadataData) : null;

      console.log('\n📋 Sync Status:');
      console.log('================');
      
      if (localStats) {
        console.log(`🏠 Local: ${new Date(localStats.mtime).toLocaleString()} (${localStats.size} bytes)`);
      } else {
        console.log('🏠 Local: Not found');
      }
      
      if (remoteMetadata) {
        console.log(`🌐 Remote: ${new Date(remoteMetadata.timestamp).toLocaleString()} (${remoteMetadata.size} bytes)`);
      } else {
        console.log('🌐 Remote: Not found');
      }

      // Determine sync direction
      if (localStats && remoteMetadata) {
        const localTime = new Date(localStats.mtime);
        const remoteTime = new Date(remoteMetadata.timestamp);
        
        if (localTime > remoteTime) {
          console.log('\n📤 Local database is newer - upload recommended');
        } else if (remoteTime > localTime) {
          console.log('\n📥 Remote database is newer - download recommended');
        } else {
          console.log('\n✅ Databases are in sync');
        }
      }
      
      return true;
    } catch (error) {
      log(`❌ Status check failed: ${error.message}`, 'red');
      return false;
    }
  }
}

// CLI interface
async function main() {
  const command = process.argv[2];
  
  if (!command) {
    console.log(`
🌐 Embedded Hive Database Remote Storage Sync

Usage: node sync-remote-storage.js <command>

Commands:
  upload     Upload local database to remote storage
  download   Download database from remote storage
  status     Show sync status
  help       Show this help message

Environment Variables:
  HIVE_STORAGE_TYPE=s3|remote    Storage backend to use
  AWS_ACCESS_KEY_ID=...          AWS credentials (for S3)
  AWS_SECRET_ACCESS_KEY=...        AWS credentials (for S3)
  HIVE_S3_BUCKET=...             S3 bucket name
  REMOTE_STORAGE_ENDPOINT=...      Remote API endpoint
  REMOTE_STORAGE_API_KEY=...      Remote API key
  ENCRYPTION_KEY=...             Encryption key (auto-generated if not provided)
`);
    process.exit(0);
  }

  const syncer = new DatabaseSyncer();
  
  if (!(await syncer.initialize())) {
    process.exit(1);
  }

  switch (command) {
    case 'upload':
      await syncer.uploadDatabase();
      break;
    case 'download':
      await syncer.downloadDatabase();
      break;
    case 'status':
      await syncer.syncStatus();
      break;
    case 'help':
      // Help already shown above
      break;
    default:
      log(`❌ Unknown command: ${command}`, 'red');
      log('Use "help" to see available commands', 'yellow');
      process.exit(1);
  }
}

// Run the script
main().catch(error => {
  log(`💥 Unhandled error: ${error.message}`, 'red');
  process.exit(1);
});