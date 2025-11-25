/**
 * Hive Storage Configuration Manager
 * This module provides unified storage configuration for embedded Hive database
 * with support for local, S3, remote API, and replication storage options.
 */

import { DiskStorage } from "hive/disk-storage";
import { S3Storage } from "hive/s3-storage";
import { RemoteStorage } from "hive/remote-storage";
import { ReplicationStorage } from "hive/replication-storage";
import { NodeDriver } from "hive/node-driver";

/**
 * Storage configuration based on environment variables
 */
export class HiveStorageConfig {
  constructor() {
    this.config = null;
    this.initialized = false;
  }

  /**
   * Get storage configuration based on environment
   */
  async getConfig() {
    if (this.config) return this.config;

    const storageType = process.env.HIVE_STORAGE_TYPE || 'disk';
    
    console.log(`🔧 Initializing Hive storage: ${storageType}`);

    switch (storageType.toLowerCase()) {
      case 's3':
        this.config = await this.createS3Storage();
        break;
      case 'remote':
        this.config = await this.createRemoteStorage();
        break;
      case 'replication':
        this.config = await this.createReplicationStorage();
        break;
      case 'disk':
      default:
        this.config = await this.createDiskStorage();
        break;
    }

    this.initialized = true;
    console.log(`✅ Hive storage initialized: ${storageType}`);
    return this.config;
  }

  /**
   * Create local disk storage
   */
  async createDiskStorage() {
    const dir = process.env.HIVE_DISK_PATH || '.blade/state';
    
    return {
      driver: new NodeDriver(),
      storage: new DiskStorage({ 
        dir,
        encryption: process.env.HIVE_ENCRYPTION_KEY ? {
          algorithm: 'aes-256-gcm',
          key: process.env.HIVE_ENCRYPTION_KEY
        } : undefined
      })
    };
  }

  /**
   * Create S3 storage
   */
  async createS3Storage() {
    try {
      const { S3Client } = await import('@aws-sdk/client-s3');
      
      if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
        throw new Error('AWS credentials required for S3 storage');
      }

      const s3Client = new S3Client({
        region: process.env.AWS_REGION || 'us-east-1',
        credentials: {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
        }
      });

      return {
        driver: new NodeDriver(),
        storage: new S3Storage({
          client: s3Client,
          bucket: process.env.HIVE_S3_BUCKET || 'hive-database',
          prefix: process.env.HIVE_S3_PREFIX || 'databases/main',
          encryption: process.env.HIVE_ENCRYPTION_KEY ? {
            algorithm: 'aes-256-gcm',
            key: process.env.HIVE_ENCRYPTION_KEY
          } : undefined
        })
      };
    } catch (error) {
      console.error('❌ Failed to initialize S3 storage:', error.message);
      console.log('📦 Install AWS SDK: npm install @aws-sdk/client-s3');
      throw error;
    }
  }

  /**
   * Create remote API storage
   */
  async createRemoteStorage() {
    if (!process.env.REMOTE_STORAGE_ENDPOINT) {
      throw new Error('Remote storage endpoint required');
    }

    return {
      driver: new NodeDriver(),
      storage: new RemoteStorage({
        endpoint: process.env.REMOTE_STORAGE_ENDPOINT,
        apiKey: process.env.REMOTE_STORAGE_API_KEY,
        encryption: process.env.HIVE_ENCRYPTION_KEY ? {
          algorithm: 'aes-256-gcm',
          key: process.env.HIVE_ENCRYPTION_KEY
        } : undefined,
        timeout: parseInt(process.env.REMOTE_STORAGE_TIMEOUT) || 30000,
        retries: parseInt(process.env.REMOTE_STORAGE_RETRIES) || 3
      })
    };
  }

  /**
   * Create replication storage (hybrid approach)
   */
  async createReplicationStorage() {
    const primary = await this.createDiskStorage();
    const replicas = [];

    // Add S3 replica if configured
    if (process.env.AWS_ACCESS_KEY_ID && process.env.HIVE_S3_BUCKET) {
      try {
        const s3Config = await this.createS3Storage();
        replicas.push(s3Config.storage);
        console.log('📤 Added S3 replica for replication');
      } catch (error) {
        console.warn('⚠️  Failed to add S3 replica:', error.message);
      }
    }

    // Add remote API replica if configured
    if (process.env.REMOTE_STORAGE_ENDPOINT) {
      try {
        const remoteConfig = await this.createRemoteStorage();
        replicas.push(remoteConfig.storage);
        console.log('📤 Added remote API replica for replication');
      } catch (error) {
        console.warn('⚠️  Failed to add remote API replica:', error.message);
      }
    }

    return {
      driver: primary.driver,
      storage: new ReplicationStorage({
        primary: primary.storage,
        replicas,
        syncMode: process.env.HIVE_REPLICATION_MODE || 'async', // sync or async
        conflictResolution: process.env.HIVE_CONFLICT_RESOLUTION || 'latest' // latest, primary, replica
      })
    };
  }

  /**
   * Get storage status and health
   */
  async getStorageStatus() {
    const config = await this.getConfig();
    const status = {
      type: process.env.HIVE_STORAGE_TYPE || 'disk',
      initialized: this.initialized,
      healthy: false,
      lastCheck: new Date().toISOString()
    };

    try {
      // Test storage by writing and reading a test file
      const testData = `hive-storage-test-${Date.now()}`;
      await config.storage.set('health-check', testData);
      const readData = await config.storage.get('health-check');
      
      status.healthy = readData === testData;
      
      // Clean up test data
      await config.storage.delete('health-check');
    } catch (error) {
      status.error = error.message;
      status.healthy = false;
    }

    return status;
  }

  /**
   * Migrate data from one storage to another
   */
  async migrateStorage(fromConfig, toConfig) {
    console.log('🔄 Starting storage migration...');
    
    try {
      // Get all data from source storage
      const allKeys = await fromConfig.storage.list();
      console.log(`📊 Found ${allKeys.length} items to migrate`);

      let migrated = 0;
      let errors = 0;

      for (const key of allKeys) {
        try {
          const data = await fromConfig.storage.get(key);
          await toConfig.storage.set(key, data);
          migrated++;
          
          if (migrated % 10 === 0) {
            console.log(`📤 Migrated ${migrated}/${allKeys.length} items...`);
          }
        } catch (error) {
          console.error(`❌ Failed to migrate ${key}:`, error.message);
          errors++;
        }
      }

      console.log(`✅ Migration completed: ${migrated} succeeded, ${errors} failed`);
      return { migrated, errors, total: allKeys.length };
    } catch (error) {
      console.error('❌ Migration failed:', error.message);
      throw error;
    }
  }

  /**
   * Create backup of current storage
   */
  async createBackup(backupName = null) {
    const config = await this.getConfig();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupKey = `backups/backup-${backupName || timestamp}`;

    try {
      // Get all data
      const allKeys = await config.storage.list();
      const backupData = {};

      for (const key of allKeys) {
        if (!key.startsWith('backups/')) { // Don't backup backups
          backupData[key] = await config.storage.get(key);
        }
      }

      // Store backup
      await config.storage.set(backupKey, JSON.stringify({
        timestamp: new Date().toISOString(),
        keys: allKeys,
        data: backupData,
        version: '1.0'
      }));

      console.log(`✅ Backup created: ${backupKey}`);
      return backupKey;
    } catch (error) {
      console.error('❌ Backup failed:', error.message);
      throw error;
    }
  }

  /**
   * Restore from backup
   */
  async restoreBackup(backupKey) {
    const config = await this.getConfig();

    try {
      const backupData = await config.storage.get(backupKey);
      const backup = JSON.parse(backupData);

      console.log(`🔄 Restoring from backup: ${backup.timestamp}`);

      for (const [key, data] of Object.entries(backup.data)) {
        await config.storage.set(key, data);
      }

      console.log(`✅ Restored ${backup.keys.length} items from backup`);
      return backup;
    } catch (error) {
      console.error('❌ Restore failed:', error.message);
      throw error;
    }
  }
}

// Singleton instance
let storageConfig = null;

/**
 * Get global storage configuration instance
 */
export async function getHiveStorageConfig() {
  if (!storageConfig) {
    storageConfig = new HiveStorageConfig();
  }
  return storageConfig;
}

/**
 * Initialize Hive with configured storage
 */
export async function createHiveWithConfiguredStorage() {
  const configManager = await getHiveStorageConfig();
  const config = await configManager.getConfig();
  
  const { Hive } = await import("hive");
  return new Hive(config);
}

// Export for direct use
// HiveStorageConfig is already exported as a class above