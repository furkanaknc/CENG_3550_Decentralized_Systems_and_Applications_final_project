import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import authRouter from "./routes/auth";
import pickupRouter from "./routes/pickups";
import courierRouter from "./routes/couriers";
import analyticsRouter from "./routes/analytics";
import mapRouter from "./routes/maps";
import adminRouter from "./routes/admin";
import { runMigrations } from "./db/migrate";
import { shutdownPool } from "./db/client";
import { seedAdmin } from "./db/admin-seed";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use("/api/auth", authRouter);
app.use("/api/pickups", pickupRouter);
app.use("/api/couriers", courierRouter);
app.use("/api/analytics", analyticsRouter);
app.use("/api/maps", mapRouter);
app.use("/api/admin", adminRouter);

const port = parseInt(process.env.PORT || "4000", 10);

async function bootstrap() {
  if (process.env.NODE_ENV === "test") {
    return;
  }

  try {
    await runMigrations();
    await seedAdmin();
    const server = app.listen(port, () => {
      console.log(`Backend listening on port ${port}`);
    });

    const gracefulShutdown = async () => {
      server.close();
      await shutdownPool();
      process.exit(0);
    };

    process.on("SIGINT", gracefulShutdown);
    process.on("SIGTERM", gracefulShutdown);
  } catch (error) {
    console.error("Failed to start backend", error);
    process.exit(1);
  }
}

void bootstrap();

export default app;
