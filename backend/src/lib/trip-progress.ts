import { eq } from "drizzle-orm";
import { db } from "../db";
import { packingItem, poll, tripTask } from "../db/schema";
import { getPollStatus } from "./polls";

const getPackingProgress = async (tripId: string, userId: string) => {
  const items = await db
    .select({ ownerId: packingItem.ownerId, isPacked: packingItem.isPacked })
    .from(packingItem)
    .where(eq(packingItem.tripId, tripId));
  const getCounts = (scoped: typeof items) => ({
    packedCount: scoped.filter((item) => item.isPacked).length,
    totalCount: scoped.length,
  });
  return {
    mine: getCounts(items.filter((item) => item.ownerId === userId)),
    shared: getCounts(items.filter((item) => item.ownerId === null)),
  };
};

const getTaskProgress = async (tripId: string) => {
  const tasks = await db
    .select({ completedAt: tripTask.completedAt })
    .from(tripTask)
    .where(eq(tripTask.tripId, tripId));
  return {
    doneCount: tasks.filter((task) => task.completedAt !== null).length,
    totalCount: tasks.length,
  };
};

const getPollProgress = async (tripId: string, userId: string) => {
  const polls = await db.query.poll.findMany({
    where: eq(poll.tripId, tripId),
    with: { votes: { columns: { userId: true } } },
  });
  const openPolls = polls.filter((record) => getPollStatus(record) === "open");
  return {
    openCount: openPolls.length,
    awaitingMyVoteCount: openPolls.filter(
      (record) => !record.votes.some((vote) => vote.userId === userId),
    ).length,
  };
};

export const getTripProgress = async (tripId: string, userId: string) => {
  const [packing, tasks, polls] = await Promise.all([
    getPackingProgress(tripId, userId),
    getTaskProgress(tripId),
    getPollProgress(tripId, userId),
  ]);
  return { packing, tasks, polls };
};
