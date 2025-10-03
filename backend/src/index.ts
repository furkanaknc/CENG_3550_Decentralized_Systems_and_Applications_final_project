import express from 'express';
import dotenv from 'dotenv';
import pickupRouter from './routes/pickups';
import courierRouter from './routes/couriers';
import analyticsRouter from './routes/analytics';

dotenv.config();

const app = express();
app.use(express.json());

app.use('/api/pickups', pickupRouter);
app.use('/api/couriers', courierRouter);
app.use('/api/analytics', analyticsRouter);

const port = process.env.PORT || 4000;

if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    console.log(`Backend listening on port ${port}`);
  });
}

export default app;
