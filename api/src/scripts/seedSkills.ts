/**
 * Seed the skill catalog with a curated set of 100 starter skills.
 * Idempotent: re-running upserts by normalized name (no duplicates).
 *   npm run seed:skills   (or: ts-node src/scripts/seedSkills.ts)
 */
import { connectDb, disconnectDb } from '../config/db';
import { Skill, normalizeSkillName } from '../models/skill.model';
import { logger } from '../utils/logger';

interface SeedSkill {
  name: string;
  category: string;
}

const SKILLS: SeedSkill[] = [
  // Music (10)
  { name: 'Guitar', category: 'Music' },
  { name: 'Piano', category: 'Music' },
  { name: 'Violin', category: 'Music' },
  { name: 'Drums', category: 'Music' },
  { name: 'Singing', category: 'Music' },
  { name: 'Bass Guitar', category: 'Music' },
  { name: 'Ukulele', category: 'Music' },
  { name: 'Music Production', category: 'Music' },
  { name: 'DJing', category: 'Music' },
  { name: 'Songwriting', category: 'Music' },

  // Cooking (10)
  { name: 'Baking', category: 'Cooking' },
  { name: 'Italian Cooking', category: 'Cooking' },
  { name: 'Sushi Making', category: 'Cooking' },
  { name: 'Vegan Cooking', category: 'Cooking' },
  { name: 'Cake Decorating', category: 'Cooking' },
  { name: 'BBQ & Grilling', category: 'Cooking' },
  { name: 'Bread Making', category: 'Cooking' },
  { name: 'Pastry Making', category: 'Cooking' },
  { name: 'Cocktail Mixing', category: 'Cooking' },
  { name: 'Meal Prep', category: 'Cooking' },

  // Languages (10)
  { name: 'English', category: 'Languages' },
  { name: 'Spanish', category: 'Languages' },
  { name: 'French', category: 'Languages' },
  { name: 'German', category: 'Languages' },
  { name: 'Mandarin Chinese', category: 'Languages' },
  { name: 'Japanese', category: 'Languages' },
  { name: 'Korean', category: 'Languages' },
  { name: 'Italian', category: 'Languages' },
  { name: 'Portuguese', category: 'Languages' },
  { name: 'Sign Language', category: 'Languages' },

  // Crafts (10)
  { name: 'Knitting', category: 'Crafts' },
  { name: 'Crochet', category: 'Crafts' },
  { name: 'Sewing', category: 'Crafts' },
  { name: 'Pottery', category: 'Crafts' },
  { name: 'Woodworking', category: 'Crafts' },
  { name: 'Origami', category: 'Crafts' },
  { name: 'Jewelry Making', category: 'Crafts' },
  { name: 'Calligraphy', category: 'Crafts' },
  { name: 'Candle Making', category: 'Crafts' },
  { name: 'Embroidery', category: 'Crafts' },

  // Art & Design (10)
  { name: 'Drawing', category: 'Art & Design' },
  { name: 'Painting', category: 'Art & Design' },
  { name: 'Watercolor', category: 'Art & Design' },
  { name: 'Digital Illustration', category: 'Art & Design' },
  { name: 'Graphic Design', category: 'Art & Design' },
  { name: 'Photography', category: 'Art & Design' },
  { name: 'Photo Editing', category: 'Art & Design' },
  { name: 'Animation', category: 'Art & Design' },
  { name: 'Sculpting', category: 'Art & Design' },
  { name: 'Comic Art', category: 'Art & Design' },

  // Fitness & Wellness (10)
  { name: 'Yoga', category: 'Fitness & Wellness' },
  { name: 'Pilates', category: 'Fitness & Wellness' },
  { name: 'Meditation', category: 'Fitness & Wellness' },
  { name: 'Weight Training', category: 'Fitness & Wellness' },
  { name: 'Running Coaching', category: 'Fitness & Wellness' },
  { name: 'HIIT', category: 'Fitness & Wellness' },
  { name: 'Mobility & Stretching', category: 'Fitness & Wellness' },
  { name: 'Nutrition Coaching', category: 'Fitness & Wellness' },
  { name: 'Boxing', category: 'Fitness & Wellness' },
  { name: 'Calisthenics', category: 'Fitness & Wellness' },

  // Dance (8)
  { name: 'Salsa', category: 'Dance' },
  { name: 'Hip Hop Dance', category: 'Dance' },
  { name: 'Ballet', category: 'Dance' },
  { name: 'Ballroom Dance', category: 'Dance' },
  { name: 'Contemporary Dance', category: 'Dance' },
  { name: 'Tango', category: 'Dance' },
  { name: 'Breakdancing', category: 'Dance' },
  { name: 'Zumba', category: 'Dance' },

  // Sports (8)
  { name: 'Tennis', category: 'Sports' },
  { name: 'Basketball', category: 'Sports' },
  { name: 'Soccer', category: 'Sports' },
  { name: 'Swimming', category: 'Sports' },
  { name: 'Rock Climbing', category: 'Sports' },
  { name: 'Cycling', category: 'Sports' },
  { name: 'Skateboarding', category: 'Sports' },
  { name: 'Golf', category: 'Sports' },

  // Technology (10)
  { name: 'Python', category: 'Technology' },
  { name: 'JavaScript', category: 'Technology' },
  { name: 'Web Development', category: 'Technology' },
  { name: 'Data Analysis', category: 'Technology' },
  { name: 'Spreadsheets (Excel)', category: 'Technology' },
  { name: 'Machine Learning', category: 'Technology' },
  { name: 'Mobile App Development', category: 'Technology' },
  { name: 'UI/UX Design', category: 'Technology' },
  { name: 'Game Development', category: 'Technology' },
  { name: 'SQL', category: 'Technology' },

  // Business & Career (8)
  { name: 'Public Speaking', category: 'Business & Career' },
  { name: 'Resume Writing', category: 'Business & Career' },
  { name: 'Digital Marketing', category: 'Business & Career' },
  { name: 'Social Media Marketing', category: 'Business & Career' },
  { name: 'Entrepreneurship', category: 'Business & Career' },
  { name: 'Project Management', category: 'Business & Career' },
  { name: 'Personal Finance', category: 'Business & Career' },
  { name: 'Negotiation', category: 'Business & Career' },

  // Lifestyle (6)
  { name: 'Gardening', category: 'Lifestyle' },
  { name: 'Chess', category: 'Lifestyle' },
  { name: 'Creative Writing', category: 'Lifestyle' },
  { name: 'Car Maintenance', category: 'Lifestyle' },
  { name: 'Interior Design', category: 'Lifestyle' },
  { name: 'Makeup Artistry', category: 'Lifestyle' },
];

async function main() {
  if (SKILLS.length !== 100) {
    logger.warn(`Seed list has ${SKILLS.length} skills (expected 100)`);
  }
  await connectDb();

  let inserted = 0;
  for (const s of SKILLS) {
    const res = await Skill.updateOne(
      { nameNormalized: normalizeSkillName(s.name) },
      {
        $setOnInsert: {
          name: s.name,
          nameNormalized: normalizeSkillName(s.name),
          category: s.category,
          aliases: [],
          status: 'approved',
        },
      },
      { upsert: true },
    );
    if (res.upsertedCount > 0) inserted += 1;
  }

  const total = await Skill.countDocuments({});
  logger.info(`Seeded skills: ${inserted} new, ${SKILLS.length - inserted} already existed`);
  logger.info(`Skill collection now has ${total} documents`);

  await disconnectDb();
}

main().catch((err) => {
  logger.error('seedSkills failed', err);
  process.exit(1);
});
