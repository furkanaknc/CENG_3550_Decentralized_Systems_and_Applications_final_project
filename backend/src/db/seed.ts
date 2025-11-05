import fs from 'fs/promises';
import path from 'path';
import { pool, shutdownPool } from './client';

const SEED_FILE = path.resolve(__dirname, '../../db/seed.sql');

async function runSeed(): Promise<void> {
  try {
    const sql = await fs.readFile(SEED_FILE, 'utf-8');
    await pool.query(sql);
    console.log('✅ Seed data başarıyla eklendi');
    
    // Eklenen verileri kontrol et
    const result = await pool.query('SELECT COUNT(*) as count FROM recycling_locations');
    console.log(`📍 Toplam ${result.rows[0].count} geri dönüşüm noktası`);
  } catch (error) {
    console.error('❌ Seed data eklenirken hata oluştu:', error);
    throw error;
  }
}

if (require.main === module) {
  runSeed()
    .then(() => shutdownPool())
    .catch((error) => {
      console.error('Seed failed', error);
      process.exitCode = 1;
      shutdownPool();
    });
}

export { runSeed };

