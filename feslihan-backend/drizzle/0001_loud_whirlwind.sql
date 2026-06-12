ALTER TYPE "public"."platform_type" ADD VALUE 'nefisyemektarifleri' BEFORE 'other';--> statement-breakpoint
CREATE TABLE "recipe_reviews" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"recipe_id" uuid NOT NULL,
	"rating" integer NOT NULL,
	"comment" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "ingredients" ADD COLUMN "default_unit" varchar(10);--> statement-breakpoint
ALTER TABLE "ingredients" ADD COLUMN "density_g_ml" real;--> statement-breakpoint
ALTER TABLE "ingredients" ADD COLUMN "gram_per_adet" real;--> statement-breakpoint
ALTER TABLE "meal_plans" ADD COLUMN "shopping_list" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "user_recipes" ADD COLUMN "is_favorite" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "recipe_reviews" ADD CONSTRAINT "recipe_reviews_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "recipe_reviews" ADD CONSTRAINT "recipe_reviews_recipe_id_recipes_id_fk" FOREIGN KEY ("recipe_id") REFERENCES "public"."recipes"("id") ON DELETE no action ON UPDATE no action;