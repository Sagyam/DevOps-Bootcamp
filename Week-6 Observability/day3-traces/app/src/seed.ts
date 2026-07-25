/**
 * Run once by the `migrate` service in docker-compose.yml, before the API
 * starts. Upserts, so re-running is harmless.
 */
import { PrismaClient } from '@prisma/client';
import { rootLogger } from './logger';

const TEAS = [
  { name: 'Masala Chiya', priceNpr: 40, stock: 200 },
  { name: 'Dudh Chiya', priceNpr: 35, stock: 200 },
  { name: 'Kalo Chiya', priceNpr: 25, stock: 200 },
  { name: 'Ilam Green', priceNpr: 90, stock: 200 },
  { name: 'Ilam Gold (limited)', priceNpr: 250, stock: 3 },
];

async function main() {
  const prisma = new PrismaClient();
  for (const tea of TEAS) {
    await prisma.tea.upsert({
      where: { name: tea.name },
      update: { priceNpr: tea.priceNpr, stock: tea.stock },
      create: tea,
    });
  }
  rootLogger.info({ count: TEAS.length }, 'menu seeded');
  await prisma.$disconnect();
}

main().catch((err) => {
  rootLogger.fatal({ err: err.message }, 'seed failed');
  process.exit(1);
});
