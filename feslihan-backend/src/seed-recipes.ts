import { db } from "./db.js";
import { recipes, ingredients, tags, platformCreators, userRecipes, users } from "./schema.js";
import { eq, sql, inArray } from "drizzle-orm";

const FESLIHAN_CREATOR = {
  username: "feslihan",
  platform: "other" as const,
  displayName: "Feslihan",
  profilePictureUrl: null,
};

interface SeedRecipe {
  slug: string;
  title: string;
  description: string;
  ingredientsWithMeasures: { name: string; amount: string; section?: string }[];
  tags: string[];
  cookingTimeMinutes: number;
  servings: number;
  cuisine: string;
  difficulty: "low" | "medium" | "high";
  caloriesTotalKcal: number;
  caloriesPerServingKcal: number;
  proteinGrams: number;
  carbsGrams: number;
  fatGrams: number;
  fiberGrams: number;
  freezerFriendly: boolean;
}

// All recipes verified against yemek.com (June 2026)
const PLATFORM_RECIPES: SeedRecipe[] = [
  {
    slug: "mercimek-corbasi",
    title: "Mercimek Çorbası",
    description:
      "1. Derin tencereye 3 yemek kaşığı ayçiçek yağı ekleyin. İri doğranmış soğanı yağ ile kavurun.\n2. Kavrulan soğanlara 1 yemek kaşığı un ekleyin, kokusu çıkıp renk alana kadar kavurun.\n3. Havuç ve patatesi ekleyip karıştırın.\n4. Tuz, karabiber ve yıkanarak süzülen mercimeği ilave edip karıştırın.\n5. 6 su bardağı sıcak suyu tencereye ekleyin.\n6. Kapağını kapatıp patates ve havuçlar yumuşayana kadar 40 dakika pişirin.\n7. El blenderından geçirerek pürüzsüz hale getirin. 5 dakika daha pişirip ocaktan alın.\n8. Ayrı tavada 3 yemek kaşığı sıvı yağ ve 2 yemek kaşığı tereyağını kızdırın. Kırmızı toz biber ekleyip 2 dakika kızdırın.\n9. Çorbayı kaseye alıp üzerine kızarmış yağdan gezdirip servis edin.",
    ingredientsWithMeasures: [
      { name: "Kırmızı Mercimek", amount: "1,5 su bardağı" },
      { name: "Soğan", amount: "1 adet (iri doğranmış)" },
      { name: "Havuç", amount: "1 adet (iri doğranmış)" },
      { name: "Patates", amount: "1 adet (büyük boy)" },
      { name: "Un", amount: "1 yemek kaşığı" },
      { name: "Ayçiçek Yağı", amount: "3 yemek kaşığı" },
      { name: "Su", amount: "6 su bardağı (sıcak)" },
      { name: "Tuz", amount: "1 tatlı kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
      { name: "Sıvı Yağ", amount: "3 yemek kaşığı", section: "Üzeri için" },
      { name: "Tereyağı", amount: "2 yemek kaşığı", section: "Üzeri için" },
      { name: "Kırmızı Toz Biber", amount: "1 tatlı kaşığı", section: "Üzeri için" },
    ],
    tags: ["çorba", "pratik", "sağlıklı", "vejetaryen", "geleneksel"],
    cookingTimeMinutes: 60,
    servings: 6,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 1740,
    caloriesPerServingKcal: 290,
    proteinGrams: 48,
    carbsGrams: 168,
    fatGrams: 60,
    fiberGrams: 30,
    freezerFriendly: true,
  },
  {
    slug: "menemen",
    title: "Menemen",
    description:
      "1. Geniş bir sahanda zeytinyağı ve tereyağını kızdırın.\n2. Doğranmış sivri biberleri ekleyip kavurun.\n3. Rendelenmiş domatesleri ilave edin.\n4. Tuz, karabiber ve pul biberi katıp suyu azalana kadar pişirin.\n5. Yumurta beyazlarını karışıma ekleyin ve sürekli karıştırın.\n6. Beyazlar piştikten sonra sarıları ilave edip 1 dakika karıştırıp ocaktan alın.\n7. Maydanoz serpiştirerek sıcak servis edin.",
    ingredientsWithMeasures: [
      { name: "Zeytinyağı", amount: "2 yemek kaşığı" },
      { name: "Tereyağı", amount: "2 yemek kaşığı" },
      { name: "Domates", amount: "3 adet (orta boy)" },
      { name: "Sivri Biber", amount: "4 adet (orta boy)" },
      { name: "Yumurta", amount: "3 adet" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "yarım çay kaşığı" },
      { name: "Pul Biber", amount: "yarım çay kaşığı" },
      { name: "Maydanoz", amount: "arzuya göre" },
    ],
    tags: ["kahvaltı", "pratik", "vejetaryen", "geleneksel"],
    cookingTimeMinutes: 20,
    servings: 4,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 592,
    caloriesPerServingKcal: 148,
    proteinGrams: 24,
    carbsGrams: 20,
    fatGrams: 36,
    fiberGrams: 5,
    freezerFriendly: false,
  },
  {
    slug: "karniyarik",
    title: "Karnıyarık",
    description:
      "1. Patlıcanları yıkayıp pijamalı şekilde soyun, tuzlu suda bekletin.\n2. Tavada zeytinyağını kızdırıp doğradığınız soğanı pembeleşene kadar kavurun. Yeşil biberi ekleyip kavurmaya devam edin.\n3. Kıymayı ekleyin, soğanlarla birlikte renk alıp suyunu çekene kadar pişirin.\n4. Sırasıyla sarımsak, domates salçası, biber salçası, tuz ve karabiber ekleyin, karıştırarak pişirin.\n5. Küp doğranmış domatesi ekleyin, 5 dakika pişirdikten sonra maydanozu ekleyip ocaktan alın.\n6. Patlıcanları kurulayıp kızgın ayçiçek yağında kızartın.\n7. Fırına dayanıklı kaba yerleştirip ortalarını yarın.\n8. Hazırlanan iç harcı bol bol doldurun.\n9. Üzerine domates ve biber dilimleri koyun.\n10. Önceden ısıtılmış 170°C fırında 20-25 dakika pişirin.",
    ingredientsWithMeasures: [
      { name: "Patlıcan", amount: "6 adet (orta boy)" },
      { name: "Kıyma", amount: "350 g" },
      { name: "Soğan", amount: "1 adet (büyük boy)" },
      { name: "Yeşil Biber", amount: "2 adet", section: "İç harcı için" },
      { name: "Sarımsak", amount: "2 diş" },
      { name: "Domates Salçası", amount: "yarım tatlı kaşığı" },
      { name: "Biber Salçası", amount: "yarım tatlı kaşığı" },
      { name: "Domates", amount: "2 adet" },
      { name: "Sivri Biber", amount: "6 adet (üzeri için)" },
      { name: "Maydanoz", amount: "1 avuç" },
      { name: "Zeytinyağı", amount: "3 yemek kaşığı" },
      { name: "Ayçiçek Yağı", amount: "1 su bardağı (kızartma için)" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
    ],
    tags: ["ana yemek", "geleneksel", "doyurucu", "et", "fırın"],
    cookingTimeMinutes: 80,
    servings: 6,
    cuisine: "turkish",
    difficulty: "medium",
    caloriesTotalKcal: 2580,
    caloriesPerServingKcal: 430,
    proteinGrams: 84,
    carbsGrams: 60,
    fatGrams: 156,
    fiberGrams: 24,
    freezerFriendly: true,
  },
  {
    slug: "imam-bayildi",
    title: "İmam Bayıldı",
    description:
      "1. Patlıcanların saplarını kesmeden alacalı soyun, tuzlu suda 10 dakika bekletin.\n2. Soğanları piyazlık, sarımsakları ince, biberleri ve domatesleri küp şeklinde doğrayın.\n3. Tavaya zeytinyağı alıp soğanları tuz ekleyerek pembeleşene dek kavurun.\n4. Domates, sarımsak, biber, toz şeker ve karabiberi ekleyip 10 dakika soteleyin.\n5. Ayrı tavada zeytinyağı ısıtıp patlıcanları arkalı önlü kızartın.\n6. Fazla yağı çektirip geniş tabanlı tencereye yan yana dizin.\n7. Patlıcan ortalarını çizip cep haline getirin, iç harcı doldurun.\n8. Üzerine sıcak su ekleyip kapağını kapatıp 20 dakika pişirin.\n9. Sos için ayrı tavada zeytinyağında rendelenmiş domatesi ve salçayı kavurarak sos yapın.\n10. Oda sıcaklığında soğutup sosla birlikte servis edin.",
    ingredientsWithMeasures: [
      { name: "Patlıcan", amount: "5 adet (kemer)" },
      { name: "Soğan", amount: "3 adet" },
      { name: "Sarımsak", amount: "8 diş" },
      { name: "Domates", amount: "4 adet" },
      { name: "Sivri Biber", amount: "4 adet" },
      { name: "Zeytinyağı", amount: "1 çay bardağı", section: "İç harcı için" },
      { name: "Toz Şeker", amount: "2 çay kaşığı" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
      { name: "Zeytinyağı", amount: "2 su bardağı", section: "Kızartma için" },
      { name: "Su", amount: "2 su bardağı (sıcak)" },
      { name: "Zeytinyağı", amount: "3 yemek kaşığı", section: "Sos için" },
      { name: "Domates", amount: "1 adet", section: "Sos için" },
      { name: "Domates Salçası", amount: "1 tatlı kaşığı", section: "Sos için" },
    ],
    tags: ["ana yemek", "geleneksel", "vegan", "vejetaryen"],
    cookingTimeMinutes: 75,
    servings: 4,
    cuisine: "turkish",
    difficulty: "medium",
    caloriesTotalKcal: 2372,
    caloriesPerServingKcal: 593,
    proteinGrams: 16,
    carbsGrams: 72,
    fatGrams: 180,
    fiberGrams: 28,
    freezerFriendly: true,
  },
  {
    slug: "kisir",
    title: "Kısır",
    description:
      "1. 2 su bardağı ince bulguru geniş bir kaseye alın. Üzerine 1,5 su bardağı sıcak suyu ekleyin.\n2. Streç film ile üzerini kapatıp bulgurların şişmesini bekleyin, yaklaşık 10-15 dakika.\n3. Bulgurlar şiştikten sonra tane tane olması için güzelce karıştırın.\n4. Üzerine 2 yemek kaşığı domates salçası ve 1 çay bardağı zeytinyağını ekleyin.\n5. 1 tatlı kaşığı tuz, 1 tatlı kaşığı pul biber, 2 limonun suyu ve yarım çay bardağı nar ekşisini ekleyin.\n6. Doğradığınız 6 dal taze soğanı, yarım demet taze nane ve maydanozu ekleyip karıştırın.\n7. Marul yapraklarıyla servis edin.",
    ingredientsWithMeasures: [
      { name: "İnce Bulgur", amount: "2 su bardağı" },
      { name: "Su", amount: "1,5 su bardağı (sıcak)" },
      { name: "Domates Salçası", amount: "2 yemek kaşığı" },
      { name: "Zeytinyağı", amount: "1 çay bardağı" },
      { name: "Tuz", amount: "1 tatlı kaşığı" },
      { name: "Pul Biber", amount: "1 tatlı kaşığı" },
      { name: "Limon", amount: "2 adet (suyu)" },
      { name: "Nar Ekşisi", amount: "yarım çay bardağı" },
      { name: "Yeşil Soğan", amount: "6 dal" },
      { name: "Maydanoz", amount: "yarım demet" },
      { name: "Taze Nane", amount: "yarım demet" },
    ],
    tags: ["meze", "salata", "pratik", "vegan", "vejetaryen", "sağlıklı", "geleneksel", "misafirler için"],
    cookingTimeMinutes: 20,
    servings: 6,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 2160,
    caloriesPerServingKcal: 360,
    proteinGrams: 36,
    carbsGrams: 288,
    fatGrams: 72,
    fiberGrams: 48,
    freezerFriendly: false,
  },
  {
    slug: "cilbir",
    title: "Çılbır",
    description:
      "1. Suyu derin tencerede kaynatıp fokurdamaya başlayınca ateşi kısarak elma sirkesi ekleyin.\n2. Yumurta sarısını bozmadan kepçeye kırıp yavaşça sirkeli suya bırakın. Akları pişip sarıları rafadan kıvamda olana kadar 3-4 dakika pişirin.\n3. Süzme yoğurda tuz ve ezilmiş sarımsağı karıştırarak servis tabaklarına dağıtın.\n4. Pişmiş yumurtaları kevgir yardımıyla alıp fazla suyu çekerek yoğurdun üzerine yerleştirin.\n5. Tereyağını tavada eritip pul biber, nane ve karabiberi ekleyin.\n6. Hafifçe köpürmeye başlayınca ocaktan alarak yumurtaların üzerine dökün.",
    ingredientsWithMeasures: [
      { name: "Su", amount: "1 litre" },
      { name: "Yumurta", amount: "2 adet" },
      { name: "Elma Sirkesi", amount: "2 yemek kaşığı" },
      { name: "Süzme Yoğurt", amount: "1 su bardağı" },
      { name: "Sarımsak", amount: "1 diş" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Tereyağı", amount: "2 yemek kaşığı" },
      { name: "Pul Biber", amount: "1 tatlı kaşığı" },
      { name: "Nane", amount: "1 tatlı kaşığı (kuru)" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
    ],
    tags: ["kahvaltı", "pratik", "vejetaryen", "geleneksel"],
    cookingTimeMinutes: 10,
    servings: 2,
    cuisine: "turkish",
    difficulty: "medium",
    caloriesTotalKcal: 426,
    caloriesPerServingKcal: 213,
    proteinGrams: 20,
    carbsGrams: 10,
    fatGrams: 32,
    fiberGrams: 1,
    freezerFriendly: false,
  },
  {
    slug: "pirinc-pilavi",
    title: "Pirinç Pilavı",
    description:
      "1. Pirinci ılık suda 30 dakika bekletip süzün.\n2. Pilav tenceresine tereyağı ekleyin.\n3. Tereyağı eridikten sonra pirinçleri ekleyip tane tane dökülmeye başlayana kadar yaklaşık 5 dakika kavurun.\n4. Sıcak suyu ekleyin, tuz ve karabiberi ilave edin.\n5. Bir kez karıştırın, kapağını kapatıp kısık ateşte suyunu çekene kadar pişirin.\n6. Su çekince üzerine temiz bir bez koyup kapağını kapatın, 15 dakika demlendirin.\n7. Kaşıkla kabartarak servis edin.",
    ingredientsWithMeasures: [
      { name: "Pirinç", amount: "2 su bardağı" },
      { name: "Tereyağı", amount: "2 yemek kaşığı" },
      { name: "Su", amount: "2 su bardağı (sıcak)" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "yarım çay kaşığı" },
    ],
    tags: ["pilav", "pratik", "geleneksel", "vejetaryen"],
    cookingTimeMinutes: 35,
    servings: 5,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 1490,
    caloriesPerServingKcal: 298,
    proteinGrams: 20,
    carbsGrams: 260,
    fatGrams: 24,
    fiberGrams: 4,
    freezerFriendly: true,
  },
  {
    slug: "etli-nohut",
    title: "Etli Nohut Yemeği",
    description:
      "1. Kuşbaşı etine 2 parmak geçecek kadar su ekleyip yumuşayana kadar haşlayın.\n2. Tereyağını sıvı yağ ile tencerede kızdırın.\n3. Doğranmış soğanı pembeleşinceye kadar kavurun.\n4. Domates salçası, biber salçası, tuz, karabiber ve toz kırmızı biberi ekleyip haşlanmış kuşbaşını ilave edin, karıştırın.\n5. Haşlanmış nohudu, 2 kepçe et suyu ve 2 su bardağı suyu ekleyip kapağını kapatıp pişirin.\n6. Etler yumuşadığında ve yemeğin suyu hafif koyulaştığında servis edin.",
    ingredientsWithMeasures: [
      { name: "Nohut", amount: "500 g (önceden ıslatılmış)" },
      { name: "Dana Eti", amount: "300 g (kuşbaşı)" },
      { name: "Soğan", amount: "1 adet" },
      { name: "Tereyağı", amount: "3 yemek kaşığı" },
      { name: "Sıvı Yağ", amount: "1 yemek kaşığı" },
      { name: "Domates Salçası", amount: "1 yemek kaşığı" },
      { name: "Biber Salçası", amount: "yarım yemek kaşığı" },
      { name: "Su", amount: "2 su bardağı" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
      { name: "Kırmızı Toz Biber", amount: "1 çay kaşığı" },
    ],
    tags: ["ana yemek", "geleneksel", "doyurucu", "et"],
    cookingTimeMinutes: 60,
    servings: 4,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 1564,
    caloriesPerServingKcal: 391,
    proteinGrams: 100,
    carbsGrams: 120,
    fatGrams: 60,
    fiberGrams: 24,
    freezerFriendly: true,
  },
  {
    slug: "taze-fasulye",
    title: "Taze Fasulye",
    description:
      "1. Soğanı küp şeklinde doğrayın, sarımsağı dilimleyin, domatesi rendeleyin. Fasulyeyi ayıklayıp doğrayın.\n2. Zeytinyağını tencerede kızdırın.\n3. Doğranmış soğan ve sarımsağı hafif renk alana kadar kavurun.\n4. Doğranmış fasulyeyi ekleyerek kavurma işlemini sürdürün.\n5. Tuz, şeker, rendelenmiş domates ve sıcak suyu ekleyip iyice karıştırın.\n6. Kapağını kapatıp fasulyeler yumuşayana kadar kısık ateşte pişirin.\n7. Ilık veya soğuk olarak servis edin.",
    ingredientsWithMeasures: [
      { name: "Taze Fasulye", amount: "600 g" },
      { name: "Zeytinyağı", amount: "5 yemek kaşığı" },
      { name: "Soğan", amount: "1 adet (büyük boy)" },
      { name: "Sarımsak", amount: "2 diş" },
      { name: "Domates", amount: "3 adet (orta boy)" },
      { name: "Su", amount: "1 su bardağı (sıcak)" },
      { name: "Toz Şeker", amount: "1 tatlı kaşığı" },
      { name: "Tuz", amount: "2 çay kaşığı" },
    ],
    tags: ["ana yemek", "geleneksel", "hafif", "sağlıklı", "vegan", "vejetaryen"],
    cookingTimeMinutes: 45,
    servings: 4,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 816,
    caloriesPerServingKcal: 204,
    proteinGrams: 12,
    carbsGrams: 52,
    fatGrams: 52,
    fiberGrams: 16,
    freezerFriendly: true,
  },
  {
    slug: "mercimek-koftesi",
    title: "Mercimek Köftesi",
    description:
      "1. Mercimeği bol suda yıkayıp 3 su bardağı sıcak suda kaynatın.\n2. Suyunu çekmeye yakın mercimeği ocaktan alın.\n3. Üzerine ince bulguru ekleyin, kapağını kapatıp 15 dakika bekletin.\n4. Zeytinyağını tavada kızdırın, kuru soğanı küp şeklinde doğrayıp tavaya aktarın, 5 dakika kavurun.\n5. Biber salçası, domates salçası, tuz, pul biber ve kimyonu ekleyip 3-4 dakika kavurun.\n6. Salçalı karışımı mercimek harcına ekleyin.\n7. Taze soğan ve maydanozu ince kıyıp ekleyin, karabiber ekleyin.\n8. Tüm malzemeleri özleşene kadar iyice yoğurun.\n9. Ceviz büyüklüğünde parçalar alıp avuç içinde şekil verin.\n10. Marul ve limonla servis edin.",
    ingredientsWithMeasures: [
      { name: "Kırmızı Mercimek", amount: "1,5 su bardağı" },
      { name: "İnce Bulgur", amount: "1,5 su bardağı" },
      { name: "Soğan", amount: "2 adet (kuru)" },
      { name: "Zeytinyağı", amount: "1 çay bardağı" },
      { name: "Biber Salçası", amount: "1 yemek kaşığı" },
      { name: "Domates Salçası", amount: "1 yemek kaşığı" },
      { name: "Yeşil Soğan", amount: "5 adet" },
      { name: "Maydanoz", amount: "yarım demet" },
      { name: "Tuz", amount: "1,5 tatlı kaşığı" },
      { name: "Pul Biber", amount: "1 çay kaşığı" },
      { name: "Kimyon", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
    ],
    tags: ["meze", "pratik", "vegan", "vejetaryen", "sağlıklı", "geleneksel", "misafirler için"],
    cookingTimeMinutes: 50,
    servings: 6,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 2088,
    caloriesPerServingKcal: 348,
    proteinGrams: 60,
    carbsGrams: 288,
    fatGrams: 48,
    fiberGrams: 42,
    freezerFriendly: true,
  },
  {
    slug: "patlican-musakka",
    title: "Patlıcan Musakka",
    description:
      "1. Patlıcanların kabuklarını alacalı soyun, halka halka kesip tuzlu suda bekletin.\n2. Tavada sıvı yağ kızdırıp doğranmış soğanı pembeleşene kadar kavurun. Çarliston biberi ekleyip kavurmaya devam edin.\n3. Kıymayı, salçayı, tuz, karabiber ve kimyonu ekleyerek karıştırın.\n4. Küp doğranmış domatesleri ekleyip tamamen pişene kadar pişirin.\n5. Geniş tabanlı tavada ayçiçek yağını kızdırıp patlıcanları her iki tarafını kızartın.\n6. Kızarmış patlıcanları tencereye dizin.\n7. Üzerine kıymalı harcı ekleyin.\n8. 1 su bardağı su ilave ederek 15 dakika pişirin.\n9. Sıcak olarak pilavla servis edin.",
    ingredientsWithMeasures: [
      { name: "Patlıcan", amount: "4 adet (orta boy)" },
      { name: "Kıyma", amount: "300 g" },
      { name: "Soğan", amount: "1 adet (orta boy)" },
      { name: "Çarliston Biber", amount: "3 adet" },
      { name: "Domates", amount: "2 adet" },
      { name: "Domates Salçası", amount: "1 yemek kaşığı" },
      { name: "Sıvı Yağ", amount: "2 yemek kaşığı" },
      { name: "Ayçiçek Yağı", amount: "1 su bardağı (kızartma için)" },
      { name: "Su", amount: "1 su bardağı" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
      { name: "Kimyon", amount: "1 çay kaşığı" },
    ],
    tags: ["ana yemek", "geleneksel", "doyurucu", "et"],
    cookingTimeMinutes: 55,
    servings: 4,
    cuisine: "turkish",
    difficulty: "medium",
    caloriesTotalKcal: 1848,
    caloriesPerServingKcal: 462,
    proteinGrams: 64,
    carbsGrams: 48,
    fatGrams: 120,
    fiberGrams: 16,
    freezerFriendly: true,
  },
  {
    slug: "izmir-kofte",
    title: "İzmir Köfte",
    description:
      "1. Ekmek içini maden suyu ile ıslatıp sıkın. Soğanı rendeleyin ve suyunu çıkarın. Maydanozu doğrayıp sarımsağı ezin.\n2. Kaseye kıyma, yumurta, ekmek içi, soğan, sarımsak, maydanoz, tuz, kimyon ve karabiberi ekleyip yoğurun. Buzdolabında dinlendirin.\n3. Patatesleri soyup iri dilimler halinde kesip sadece dışları renk alana kadar sıvı yağda kızartın.\n4. Harcı çıkartıp ceviz büyüklüğünde köfteler yapın, tereyağında dışları renk alana kadar kızartın.\n5. Aynı tavada domates salçası ve rendelenmiş domatesi kavurup sıcak su, tuz, karabiber ve kekik ekleyin.\n6. Fırın tepsisini bir patates bir köfte sırasıyla doldurup biberi ve domatesleri yerleştirin, sosu gezdirin.\n7. 200°C fırında üstü kızarana kadar yaklaşık 20 dakika pişirip sıcak servis edin.",
    ingredientsWithMeasures: [
      { name: "Dana Kıyma", amount: "500 g (köftelik)", section: "Köfte harcı" },
      { name: "Soğan", amount: "1 adet", section: "Köfte harcı" },
      { name: "Sarımsak", amount: "1 diş", section: "Köfte harcı" },
      { name: "Bayat Ekmek İçi", amount: "yarım adet", section: "Köfte harcı" },
      { name: "Maden Suyu", amount: "yarım çay bardağı", section: "Köfte harcı" },
      { name: "Yumurta", amount: "1 adet", section: "Köfte harcı" },
      { name: "Maydanoz", amount: "çeyrek demet", section: "Köfte harcı" },
      { name: "Tuz", amount: "1,5 çay kaşığı", section: "Köfte harcı" },
      { name: "Kimyon", amount: "1 tutam", section: "Köfte harcı" },
      { name: "Karabiber", amount: "yarım çay kaşığı", section: "Köfte harcı" },
      { name: "Patates", amount: "4 adet" },
      { name: "Sivri Biber", amount: "4 adet" },
      { name: "Domates", amount: "2 adet" },
      { name: "Sıvı Yağ", amount: "2 su bardağı (kızartma için)" },
      { name: "Tereyağı", amount: "2 yemek kaşığı" },
      { name: "Domates Salçası", amount: "1 yemek kaşığı", section: "Sos için" },
      { name: "Domates", amount: "1 su bardağı (rendesi)", section: "Sos için" },
      { name: "Su", amount: "1 su bardağı (sıcak)", section: "Sos için" },
      { name: "Kekik", amount: "1 çay kaşığı", section: "Sos için" },
    ],
    tags: ["ana yemek", "geleneksel", "doyurucu", "et", "fırın"],
    cookingTimeMinutes: 75,
    servings: 4,
    cuisine: "turkish",
    difficulty: "medium",
    caloriesTotalKcal: 2800,
    caloriesPerServingKcal: 700,
    proteinGrams: 96,
    carbsGrams: 120,
    fatGrams: 168,
    fiberGrams: 16,
    freezerFriendly: true,
  },
  {
    slug: "su-boregi",
    title: "Su Böreği",
    description:
      "1. Yumurtaları kaseye kırıp tuzu ekleyin, karıştırın. Unu ekleyip yoğurun.\n2. Tezgahta unlayıp bezeleri mandalina büyüklüğünde ayırın, poşetle kapatıp 30 dakika bekletin.\n3. Tereyağı ve sıvı yağı ocakta eritin.\n4. İlk bezeyi açıp ince yufka yapın, tepsi tabanına yağ sürüp yağlı kağıt serip yufkayı serin.\n5. Derin tencerede su, tuz ve yağ kaynatın. İkinci bezeyi kaynayan suya atıp 30 saniye kaynatın.\n6. Buzlu suya atıp suyunu hafifçe sıkın, ilk katın üzerine serin.\n7. Yağ sürüp peynir harcı koyarak katmanları tamamlayın.\n8. Üst kata yağ sürüp 210°C'de alt-üst ayarında 1 saat 15 dakika pişirin.\n9. Çıkardıktan sonra üzerine mutfak havlusu serip 10 dakika bekletin.\n10. Dilimleyerek servis edin.",
    ingredientsWithMeasures: [
      { name: "Un", amount: "3,5 su bardağı", section: "Hamur için" },
      { name: "Yumurta", amount: "6 adet", section: "Hamur için" },
      { name: "Tuz", amount: "1,5 tatlı kaşığı", section: "Hamur için" },
      { name: "Beyaz Peynir", amount: "600 g", section: "İç harcı için" },
      { name: "Tereyağı", amount: "125 g", section: "Ara katlar için" },
      { name: "Sıvı Yağ", amount: "yarım çay bardağı", section: "Ara katlar için" },
      { name: "Su", amount: "1,5 litre (haşlama için)" },
    ],
    tags: ["hamur işi", "kahvaltı", "geleneksel", "doyurucu", "vejetaryen", "misafirler için", "fırın"],
    cookingTimeMinutes: 120,
    servings: 8,
    cuisine: "turkish",
    difficulty: "high",
    caloriesTotalKcal: 4064,
    caloriesPerServingKcal: 508,
    proteinGrams: 128,
    carbsGrams: 280,
    fatGrams: 200,
    fiberGrams: 8,
    freezerFriendly: true,
  },
  {
    slug: "yaprak-sarma",
    title: "Zeytinyağlı Yaprak Sarma",
    description:
      "1. Zeytinyağını kızdırıp rendelenmiş soğanı kavurun, dolmalık fıstığı ekleyip kavurmaya devam edin.\n2. Ilık suda bekletilen pirinci soğanla birlikte şeffaf görünüm kazanana kadar kavurun.\n3. Kuş üzümü, tuz, karabiber, yenibahar ve tarçını sırasıyla ekleyip karıştırın.\n4. Sıcak suyu ilave edip iç harcı kısık ateşte 5 dakika pişirin, ocaktan alın.\n5. Asma yapraklarını damarlı kısımları üste gelecek şekilde açın.\n6. Her yaprağın ortasına tatlı kaşığı kadar iç harç yerleştirin.\n7. Kenarları içe alıp geniş kısmından uç kısmına doğru sıkıca sarın.\n8. Tencere tabanını asma yaprağıyla kaplayıp sarmaları yan yana dizin, limon dilimleri yerleştirin.\n9. Üzerine porselen tabak kapatıp sıcak su ve zeytinyağı ekleyerek kısık ateşte 35 dakika pişirin.\n10. Ilık ya da soğuk olarak servis edin.",
    ingredientsWithMeasures: [
      { name: "Asma Yaprağı", amount: "300 g" },
      { name: "Pirinç", amount: "1,5 su bardağı" },
      { name: "Soğan", amount: "3 adet (orta boy)" },
      { name: "Zeytinyağı", amount: "yarım su bardağı", section: "İç harç için" },
      { name: "Dolmalık Fıstık", amount: "1 yemek kaşığı" },
      { name: "Kuş Üzümü", amount: "1 yemek kaşığı" },
      { name: "Su", amount: "1 su bardağı (sıcak)", section: "İç harç için" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
      { name: "Nane", amount: "1 çay kaşığı (kuru)" },
      { name: "Yenibahar", amount: "1 çay kaşığı" },
      { name: "Tarçın", amount: "yarım çay kaşığı" },
      { name: "Limon", amount: "1 adet" },
      { name: "Zeytinyağı", amount: "4 yemek kaşığı", section: "Pişirme için" },
      { name: "Su", amount: "1,5 su bardağı (sıcak)", section: "Pişirme için" },
    ],
    tags: ["meze", "geleneksel", "vegan", "vejetaryen", "misafirler için"],
    cookingTimeMinutes: 85,
    servings: 4,
    cuisine: "turkish",
    difficulty: "high",
    caloriesTotalKcal: 2256,
    caloriesPerServingKcal: 564,
    proteinGrams: 28,
    carbsGrams: 240,
    fatGrams: 112,
    fiberGrams: 16,
    freezerFriendly: true,
  },
  {
    slug: "ezogelin-corbasi",
    title: "Ezogelin Çorbası",
    description:
      "1. Sıcak suyu geniş tencerede kaynatın. Yıkayıp süzdürülen mercimeği ekleyin.\n2. Pirinç, bulgur ve tuzu tencereye aktarın.\n3. Yaklaşık 35 dakika mercimekler yumuşayana kadar pişirin.\n4. Ayrı tavada tereyağını eritin.\n5. Küp doğranmış kuru soğanı ekleyip kavurun.\n6. Domates salçasını ekleyin.\n7. Naneyi ilave edip 2 dakika daha kavurun.\n8. Kavrulan karışımı tencereye ekleyin.\n9. Hızlıca karıştırıp 10 dakika daha pişirin.\n10. Limon suyu ve pul biber ilavesiyle sıcak servis edin.",
    ingredientsWithMeasures: [
      { name: "Kırmızı Mercimek", amount: "2 çay bardağı" },
      { name: "Pirinç", amount: "3 yemek kaşığı" },
      { name: "İnce Bulgur", amount: "2 yemek kaşığı" },
      { name: "Soğan", amount: "1 adet" },
      { name: "Tereyağı", amount: "1 yemek kaşığı" },
      { name: "Domates Salçası", amount: "1 tatlı kaşığı" },
      { name: "Nane", amount: "1 tatlı kaşığı (kuru)" },
      { name: "Tuz", amount: "1 tatlı kaşığı" },
      { name: "Su", amount: "9 su bardağı (sıcak)" },
      { name: "Limon", amount: "yarım adet (suyu)", section: "Servis için" },
      { name: "Pul Biber", amount: "1 tatlı kaşığı", section: "Servis için" },
    ],
    tags: ["çorba", "pratik", "hafif", "sağlıklı", "vegan", "vejetaryen", "geleneksel"],
    cookingTimeMinutes: 45,
    servings: 6,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 696,
    caloriesPerServingKcal: 116,
    proteinGrams: 36,
    carbsGrams: 108,
    fatGrams: 10,
    fiberGrams: 18,
    freezerFriendly: true,
  },
  {
    slug: "tavuk-sote",
    title: "Tavuk Sote",
    description:
      "1. Tavada sıvı yağı kızdırıp kuşbaşı doğranmış tavuk göğsünü yüksek ateşte kavurun.\n2. Doğranmış soğanı ekleyip kavurmaya devam edin.\n3. Doğranmış yeşil biber ve kırmızı biberi ekleyin.\n4. Doğranmış domatesi ekleyin.\n5. Suyunu salınca tuz, karabiber, pul biber ve kuru naneyi ekleyip karıştırın.\n6. Tamamen pişene kadar pişirip sıcak servis edin.",
    ingredientsWithMeasures: [
      { name: "Tavuk Göğsü", amount: "300 g (kuşbaşı)" },
      { name: "Sıvı Yağ", amount: "2 yemek kaşığı" },
      { name: "Soğan", amount: "1 adet" },
      { name: "Yeşil Biber", amount: "1 adet" },
      { name: "Kırmızı Biber", amount: "yarım adet" },
      { name: "Domates", amount: "1 adet" },
      { name: "Tuz", amount: "1 çay kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
      { name: "Pul Biber", amount: "1 çay kaşığı" },
      { name: "Kuru Nane", amount: "1 çay kaşığı" },
    ],
    tags: ["ana yemek", "pratik", "tavuk", "doyurucu", "sağlıklı"],
    cookingTimeMinutes: 25,
    servings: 2,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 590,
    caloriesPerServingKcal: 295,
    proteinGrams: 60,
    carbsGrams: 16,
    fatGrams: 30,
    fiberGrams: 4,
    freezerFriendly: true,
  },
  {
    slug: "sulu-patates",
    title: "Sulu Patates Yemeği",
    description:
      "1. Patateslerin kabuklarını soyup küp halinde doğrayın.\n2. Tencerede sıvı yağı kızdırıp yemeklik doğranmış soğanı pembeleşene kadar kavurun.\n3. Salçayı ekleyip kokusu çıkana kadar kavurun.\n4. Patatesleri ekleyin, tuz ve karabiberi ilave edin.\n5. 3 su bardağı sıcak su ekleyip pişirmeye başlayın.\n6. Patatesler yumuşayana kadar kısık ateşte pişirin.\n7. Pilavla servis edin.",
    ingredientsWithMeasures: [
      { name: "Patates", amount: "3 adet (orta boy)" },
      { name: "Soğan", amount: "1 adet" },
      { name: "Domates Salçası", amount: "2 yemek kaşığı" },
      { name: "Sıvı Yağ", amount: "3 yemek kaşığı" },
      { name: "Su", amount: "3 su bardağı (sıcak)" },
      { name: "Tuz", amount: "1 tatlı kaşığı" },
      { name: "Karabiber", amount: "1 çay kaşığı" },
    ],
    tags: ["ana yemek", "pratik", "geleneksel", "vegan", "vejetaryen", "çocuklar için"],
    cookingTimeMinutes: 35,
    servings: 4,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 680,
    caloriesPerServingKcal: 170,
    proteinGrams: 8,
    carbsGrams: 96,
    fatGrams: 36,
    fiberGrams: 12,
    freezerFriendly: true,
  },
  {
    slug: "sutlac",
    title: "Sütlaç",
    description:
      "1. Yıkadığınız pirinci tencereye alarak 2 su bardağı sıcak su ekleyin. Kısık ateşte pişirmeye başlayın, ara ara nazikçe karıştırın.\n2. Pirinç lapa hale gelince 1 litre sütü ilave edin. Süt kaynayana kadar karıştırmaya devam edin, ardından kısık ateşte 8-10 dakika daha pişirin.\n3. Şekeri ekleyip karıştırın. Kaynamasını bekleyin ve 4-5 dakika daha kısık ateşte kaynatın.\n4. Nişastayı 1 çay bardağı suyla karıştırıp hazırlayın.\n5. Nişasta karışımını azar azar tencereye ekleyin, karıştırarak pişirin. Yüzeyde baloncuklar görününce 1-2 dakika daha pişirip ocaktan alın.\n6. Sütlaç harcını kepçeyle kaselere dağıtın.\n7. Oda sıcaklığında soğuduktan sonra buzdolabında en az 2 saat bekletin. Tarçın serperek servis edin.",
    ingredientsWithMeasures: [
      { name: "Pirinç", amount: "yarım çay bardağı (40 g)" },
      { name: "Su", amount: "2 su bardağı (sıcak)" },
      { name: "Süt", amount: "1 litre" },
      { name: "Toz Şeker", amount: "1 su bardağı (180 g)" },
      { name: "Buğday Nişastası", amount: "2 yemek kaşığı (tepeleme)" },
      { name: "Su", amount: "1 çay bardağı (nişasta için)" },
      { name: "Tarçın", amount: "servis için" },
    ],
    tags: ["tatlı", "geleneksel", "vejetaryen", "çocuklar için", "misafirler için"],
    cookingTimeMinutes: 36,
    servings: 6,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 1590,
    caloriesPerServingKcal: 265,
    proteinGrams: 30,
    carbsGrams: 276,
    fatGrams: 30,
    fiberGrams: 0,
    freezerFriendly: false,
  },
  {
    slug: "domates-corbasi",
    title: "Domates Çorbası",
    description:
      "1. Tavada 1 yemek kaşığı tereyağını eritin.\n2. Un ekleyin ve kokusu çıkana kadar kısık ateşte kavurun.\n3. 5 adet büyük boy rendelenmiş domatesi ekleyip 5 dakika pişirin.\n4. Sıcak et suyunu ve tuzu ilave edin. Başka bir cezvede ısıttığınız sütü azar azar ekleyerek hızlıca karıştırın.\n5. Orta ateşte kaynatıp ardından kısık ateşte 15 dakika pişirin.\n6. Blenderdan geçirerek pürüzsüz hale getirin.\n7. Servis kaselerine alıp rendelenmiş kaşar peyniri serperek sıcak servis edin.",
    ingredientsWithMeasures: [
      { name: "Domates", amount: "5 adet (büyük boy)" },
      { name: "Tereyağı", amount: "1 yemek kaşığı" },
      { name: "Un", amount: "2 yemek kaşığı" },
      { name: "Et Suyu", amount: "4 su bardağı (sıcak)" },
      { name: "Süt", amount: "2 çay bardağı (sıcak)" },
      { name: "Tuz", amount: "2 çay kaşığı" },
      { name: "Kaşar Peyniri", amount: "1 su bardağı (rendelenmiş, servis için)" },
    ],
    tags: ["çorba", "pratik", "vejetaryen", "geleneksel", "çocuklar için"],
    cookingTimeMinutes: 30,
    servings: 6,
    cuisine: "turkish",
    difficulty: "low",
    caloriesTotalKcal: 1188,
    caloriesPerServingKcal: 198,
    proteinGrams: 36,
    carbsGrams: 72,
    fatGrams: 48,
    fiberGrams: 12,
    freezerFriendly: true,
  },
  {
    slug: "kuzu-tandir",
    title: "Kuzu Tandır",
    description:
      "1. Kuzu kolun uç kısımlarındaki tüyleri yakın, üst yağların bir kısmını inceltin.\n2. Yağlı üst kısmına bıçak ile derin olmayan çizikler atın.\n3. Ufak kasede zeytinyağı, ezilmiş sarımsak, tuz, karabiber ve kekiği karıştırın.\n4. Karışımı kuzu kolun üzerine dökün ve masaj yaparak sosu ete nüfuz ettirin.\n5. Yağlı kağıtları 3 kat halinde suyun altında ıslatıp sıkın, kuzu kolu sıkıca sarın.\n6. Alüminyum folyo ile kaplayın.\n7. Fırın teline yağlı kısım altta olacak şekilde yerleştirin.\n8. 220°C fırının tabanına tepsi koyup sıcak su ile doldurun.\n9. 220°C'de 2,5 saat, ardından 120°C'ye indirerek 1 saat daha pişirin.\n10. Pişen kolu dikkatlice açıp kemiklerinden ayırarak pilav veya fırında patatesle servis edin.",
    ingredientsWithMeasures: [
      { name: "Kuzu Kol", amount: "1 adet (kemikli, yaklaşık 2 kg)" },
      { name: "Sarımsak", amount: "2 diş" },
      { name: "Zeytinyağı", amount: "yarım çay bardağı" },
      { name: "Tuz", amount: "3 çay kaşığı" },
      { name: "Karabiber", amount: "2 çay kaşığı (taze çekilmiş)" },
      { name: "Kekik", amount: "1 çay kaşığı" },
    ],
    tags: ["ana yemek", "geleneksel", "doyurucu", "et", "fırın", "misafirler için"],
    cookingTimeMinutes: 210,
    servings: 6,
    cuisine: "turkish",
    difficulty: "medium",
    caloriesTotalKcal: 3600,
    caloriesPerServingKcal: 600,
    proteinGrams: 180,
    carbsGrams: 6,
    fatGrams: 240,
    fiberGrams: 0,
    freezerFriendly: true,
  },
];

// Helper: resolve ingredient names to IDs, creating new ones if needed
async function resolveIngredientIds(
  names: string[]
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  if (names.length === 0) return map;

  const unique = [...new Set(names)];

  const existing = await db
    .select({ id: ingredients.id, name: ingredients.name })
    .from(ingredients)
    .where(inArray(ingredients.name, unique));

  for (const r of existing) map.set(r.name, r.id);

  const missing = unique.filter((n) => !map.has(n));
  if (missing.length > 0) {
    const inserted = await db
      .insert(ingredients)
      .values(missing.map((name) => ({ name })))
      .onConflictDoNothing()
      .returning();
    for (const r of inserted) map.set(r.name, r.id);

    const stillMissing = missing.filter((n) => !map.has(n));
    if (stillMissing.length > 0) {
      const refetched = await db
        .select({ id: ingredients.id, name: ingredients.name })
        .from(ingredients)
        .where(inArray(ingredients.name, stillMissing));
      for (const r of refetched) map.set(r.name, r.id);
    }
  }

  return map;
}

async function resolveTagIds(names: string[]): Promise<string[]> {
  if (names.length === 0) return [];
  const rows = await db
    .select({ id: tags.id, name: tags.name })
    .from(tags)
    .where(inArray(tags.name, names));
  const nameToId = new Map(rows.map((r) => [r.name, r.id]));
  return names.map((n) => nameToId.get(n)).filter(Boolean) as string[];
}

export async function seedPlatformRecipes(): Promise<void> {
  await db
    .insert(platformCreators)
    .values(FESLIHAN_CREATOR)
    .onConflictDoNothing();

  const existingUrls = await db
    .select({ url: recipes.url })
    .from(recipes)
    .where(sql`${recipes.url} LIKE 'feslihan://%'`);
  const existingSet = new Set(existingUrls.map((r) => r.url));

  const toInsert = PLATFORM_RECIPES.filter(
    (r) => !existingSet.has(`feslihan://${r.slug}`)
  );

  if (toInsert.length === 0) {
    console.log(`[Seed] All ${PLATFORM_RECIPES.length} platform recipes already exist`);
    return;
  }

  const allIngNames = new Set<string>();
  for (const r of toInsert) {
    for (const i of r.ingredientsWithMeasures) allIngNames.add(i.name);
  }
  const ingMap = await resolveIngredientIds([...allIngNames]);

  for (const r of toInsert) {
    const tagIds = await resolveTagIds(r.tags);
    const ingWithMeasures = r.ingredientsWithMeasures.map((i) => ({
      name: i.name,
      amount: i.amount,
      ...(i.section ? { section: i.section } : {}),
      ingredient_id: ingMap.get(i.name) ?? "",
    }));
    const ingWithoutMeasures = r.ingredientsWithMeasures
      .map((i) => ingMap.get(i.name))
      .filter(Boolean) as string[];

    await db.insert(recipes).values({
      platform: "other",
      platformUser: "feslihan",
      url: `feslihan://${r.slug}`,
      title: r.title,
      description: r.description,
      ingredientsWithMeasures: ingWithMeasures,
      ingredientsWithoutMeasures: [...new Set(ingWithoutMeasures)],
      tags: tagIds,
      cookingTimeMinutes: r.cookingTimeMinutes,
      servings: r.servings,
      cuisine: r.cuisine,
      difficulty: r.difficulty,
      caloriesTotalKcal: r.caloriesTotalKcal,
      caloriesPerServingKcal: r.caloriesPerServingKcal,
      proteinGrams: r.proteinGrams,
      carbsGrams: r.carbsGrams,
      fatGrams: r.fatGrams,
      fiberGrams: r.fiberGrams,
      freezerFriendly: r.freezerFriendly,
      requestedBy: "system",
      saveCount: 0,
    });
  }

  console.log(`[Seed] Inserted ${toInsert.length} platform recipes`);
}

export async function getPlatformRecipeIds(): Promise<string[]> {
  const rows = await db
    .select({ id: recipes.id })
    .from(recipes)
    .where(sql`${recipes.url} LIKE 'feslihan://%'`);
  return rows.map((r) => r.id);
}

export async function mapPlatformRecipesToUser(userId: string): Promise<number> {
  const recipeIds = await getPlatformRecipeIds();
  if (recipeIds.length === 0) return 0;

  let mapped = 0;
  for (const recipeId of recipeIds) {
    const inserted = await db
      .insert(userRecipes)
      .values({ userId, recipeId })
      .onConflictDoNothing()
      .returning();
    if (inserted.length > 0) mapped++;
  }

  return mapped;
}
