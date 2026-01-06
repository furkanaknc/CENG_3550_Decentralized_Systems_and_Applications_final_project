import { query } from "./client";
import { v4 as uuid } from "uuid";

export async function seedAdmin(): Promise<void> {
  const adminWallet = process.env.ADMIN_WALLET_ADDRESS;
  const adminName = process.env.ADMIN_NAME || "Platform Admin";

  if (!adminWallet) {
    console.log("⚠️  ADMIN_WALLET_ADDRESS not set, skipping admin seed");
    return;
  }

  const walletLower = adminWallet.toLowerCase();

  try {
    const { rows: existing } = await query<{ id: string }>(
      "SELECT id FROM users WHERE wallet_address = $1 LIMIT 1",
      [walletLower]
    );

    if (existing.length > 0) {
      await query(
        `UPDATE users SET role = 'admin', updated_at = NOW() WHERE wallet_address = $1`,
        [walletLower]
      );
      console.log("✅ Admin user already exists, role verified");
      return;
    }

    const adminId = `admin-${uuid()}`;
    const email = `admin+${adminId.substring(6, 18)}@greencycle.local`;

    await query(
      `INSERT INTO users (id, name, email, wallet_address, role, green_points)
       VALUES ($1, $2, $3, $4, 'admin', 1000)`,
      [adminId, adminName, email, walletLower]
    );

    console.log(`✅ Admin user seeded: ${adminName} (${walletLower})`);
  } catch (error) {
    console.error("❌ Failed to seed admin user:", error);
    throw error;
  }
}
