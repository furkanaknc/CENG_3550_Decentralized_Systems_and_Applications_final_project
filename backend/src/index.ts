import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import pickupRouter from './routes/pickups';
import courierRouter from './routes/couriers';
import analyticsRouter from './routes/analytics';
import mapRouter from './routes/maps';
import { runMigrations } from './db/migrate';
import { shutdownPool } from './db/client';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/pickups', pickupRouter);
app.use('/api/couriers', courierRouter);
app.use('/api/analytics', analyticsRouter);
app.use('/api/maps', mapRouter);

const port = parseInt(process.env.PORT || '4000', 10);

async function bootstrap() {
  if (process.env.NODE_ENV === 'test') {
    return;
  }

  try {
    await runMigrations();
    const server = app.listen(port, () => {
      console.log(`Backend listening on port ${port}`);
    });

    const gracefulShutdown = async () => {
      server.close();
      await shutdownPool();
      process.exit(0);
    };

    process.on('SIGINT', gracefulShutdown);
    process.on('SIGTERM', gracefulShutdown);
  } catch (error) {
    console.error('Failed to start backend', error);
    process.exit(1);
  }
}

void bootstrap();

export default app;
