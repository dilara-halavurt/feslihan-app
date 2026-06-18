import "dotenv/config";
import OpenAI from "openai";
import { db } from "./db.js";
import { recipes } from "./schema.js";
import { sql, isNull, eq } from "drizzle-orm";
import { uploadImage } from "./s3.js";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const PHOTO_PROMPTS: Record<string, string> = {
  "mercimek-corbasi":
    "Overhead photo of a bowl of Turkish red lentil soup (mercimek çorbası) with a drizzle of paprika butter on top, served with lemon wedges on the side. Warm, rustic ceramic bowl on a wooden table. Natural lighting, food photography style.",
  "menemen":
    "Top-down photo of Turkish menemen (scrambled eggs with tomatoes and peppers) in a traditional copper pan. Vibrant red and green colors, fresh parsley garnish. Rustic breakfast table setting with bread slices. Natural lighting, food photography.",
  "karniyarik":
    "Photo of Turkish karnıyarık (stuffed eggplants with ground meat) arranged on a white plate. Split eggplants filled with seasoned meat, topped with tomato slices. Golden-brown baked finish. Warm kitchen lighting, food photography.",
  "imam-bayildi":
    "Photo of Turkish imam bayıldı (stuffed eggplants with onion and tomato) on a ceramic plate. Olive oil glistening on top, rich vegetable filling visible. Served cold with fresh parsley. Mediterranean style, food photography.",
  "kisir":
    "Overhead photo of Turkish kısır (bulgur salad) served on a lettuce-lined plate. Red-tinted fine bulgur with fresh herbs, green onions visible. Lemon wedges on the side. Colorful, fresh, food photography.",
  "cilbir":
    "Photo of Turkish çılbır (poached eggs on garlic yogurt) on a white plate. Two perfectly poached eggs on creamy yogurt, drizzled with paprika-infused melted butter. Elegant breakfast, food photography.",
  "pirinc-pilavi":
    "Photo of fluffy Turkish pirinç pilavı (buttered rice pilaf) shaped in a dome on a plate, each grain separate and glistening. Small pat of butter melting on top. Classic side dish, warm lighting, food photography.",
  "etli-nohut":
    "Photo of Turkish etli nohut yemeği (chickpea stew with meat) in a deep bowl. Tender meat cubes and chickpeas in a rich tomato-based sauce. Served with rice pilaf on the side. Hearty, home-cooking style, food photography.",
  "taze-fasulye":
    "Photo of Turkish zeytinyağlı taze fasulye (green beans in olive oil) in a ceramic bowl. Tender green beans in a light tomato sauce, glistening with olive oil. Home-style Turkish cooking, food photography.",
  "mercimek-koftesi":
    "Photo of Turkish mercimek köftesi (red lentil balls) arranged on a plate lined with fresh lettuce leaves. Orange-red oval-shaped köfte with green herbs visible. Lemon wedges on side. Colorful appetizer, food photography.",
  "patlican-musakka":
    "Photo of Turkish patlıcan musakka (eggplant moussaka with ground meat) in a serving dish. Layers of fried eggplant and seasoned ground meat visible. Rich, hearty comfort food. Warm lighting, food photography.",
  "izmir-kofte":
    "Photo of Turkish İzmir köfte in a baking dish. Meatballs nestled between potato slices, peppers and tomatoes, all in a rich tomato sauce. Golden-brown from oven. Hearty, food photography.",
  "su-boregi":
    "Photo of Turkish su böreği (water börek) cut into squares on a serving plate. Flaky golden layers with white cheese filling visible. Crispy top, soft layers. Traditional breakfast pastry, food photography.",
  "yaprak-sarma":
    "Photo of Turkish zeytinyağlı yaprak sarma (stuffed grape leaves) arranged in a circle on a plate. Tight, uniform rolls glistening with olive oil. Lemon slices as garnish. Elegant appetizer, food photography.",
  "ezogelin-corbasi":
    "Photo of Turkish Ezogelin çorbası (Ezogelin soup) in a ceramic bowl. Thick, reddish-orange soup with a swirl of paprika butter and dried mint on top. Lemon wedge on side. Comforting, food photography.",
  "tavuk-sote":
    "Photo of Turkish tavuk sote (chicken sauté) on a plate. Diced chicken with colorful peppers, onions and tomatoes in a savory sauce. Served alongside rice pilaf. Home cooking, food photography.",
  "sulu-patates":
    "Photo of Turkish sulu patates yemeği (potato stew) in a bowl. Soft potato cubes in a light red tomato-paste broth. Simple, comforting home-style dish. Warm lighting, food photography.",
  "sutlac":
    "Photo of Turkish sütlaç (rice pudding) in individual ceramic ramekins. Creamy white surface with golden-brown caramelized top, sprinkled with cinnamon. Elegant dessert, food photography.",
  "domates-corbasi":
    "Photo of Turkish domates çorbası (tomato soup) in a white bowl. Smooth, vibrant red soup topped with shredded kaşar cheese melting on top. Warm, comforting. Food photography.",
  "kuzu-tandir":
    "Photo of Turkish kuzu tandır (slow-roasted lamb) on a serving platter. Fall-apart tender lamb with crispy edges, golden brown. Served with rice pilaf. Feast-worthy presentation, food photography.",
};

async function generatePhotos() {
  // Get all feslihan recipes without thumbnails
  const feslihanRecipes = await db
    .select({ id: recipes.id, url: recipes.url, title: recipes.title, thumbnailUrl: recipes.thumbnailUrl })
    .from(recipes)
    .where(sql`${recipes.url} LIKE 'feslihan://%'`);

  const needPhotos = feslihanRecipes.filter((r) => !r.thumbnailUrl);
  console.log(`Found ${feslihanRecipes.length} platform recipes, ${needPhotos.length} need photos`);

  if (needPhotos.length === 0) {
    console.log("All recipes already have photos!");
    return;
  }

  for (const recipe of needPhotos) {
    const slug = recipe.url.replace("feslihan://", "");
    const prompt = PHOTO_PROMPTS[slug];

    if (!prompt) {
      console.log(`  [SKIP] No prompt for ${slug}`);
      continue;
    }

    console.log(`  [GEN] ${recipe.title} (${slug})...`);

    try {
      const response = await openai.images.generate({
        model: "gpt-image-1",
        prompt,
        n: 1,
        size: "1024x1024",
        quality: "low",
      });

      const b64 = response.data?.[0]?.b64_json;
      if (!b64) {
        console.log(`  [FAIL] No image data for ${slug}`);
        continue;
      }

      // Upload to S3
      const s3Url = await uploadImage(b64, "image/png");
      console.log(`  [S3] Uploaded: ${s3Url}`);

      // Update recipe
      await db
        .update(recipes)
        .set({ thumbnailUrl: s3Url })
        .where(eq(recipes.id, recipe.id));

      console.log(`  [OK] ${recipe.title}`);
    } catch (err: any) {
      console.error(`  [ERR] ${recipe.title}: ${err.message}`);
    }
  }

  console.log("Done generating photos!");
}

generatePhotos()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Fatal:", err);
    process.exit(1);
  });
