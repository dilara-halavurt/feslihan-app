import "dotenv/config";
import { uploadImage } from "./s3.js";
import { db } from "./db.js";
import { platformCreators } from "./schema.js";
import { eq } from "drizzle-orm";
import { readFileSync } from "fs";

async function main() {
  const icon = readFileSync("../Feslihan/Assets.xcassets/AppIcon.appiconset/appicon.png");
  const b64 = icon.toString("base64");
  const url = await uploadImage(b64, "image/png");
  console.log("Uploaded:", url);

  await db
    .update(platformCreators)
    .set({ profilePictureUrl: url })
    .where(eq(platformCreators.username, "feslihan"));
  console.log("Updated feslihan creator profile picture");
  process.exit(0);
}

main();
