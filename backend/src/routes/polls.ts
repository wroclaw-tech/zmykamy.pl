import { and, asc, desc, eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db";
import { poll, pollOption, pollVote } from "../db/schema";
import type { AppEnv } from "../lib/app-env";
import { getFirstRow } from "../lib/db-rows";
import { ApiError } from "../lib/errors";
import { getPollStatus } from "../lib/polls";
import { validate } from "../lib/validation";
import { requireAuth } from "../middleware/require-auth";
import { createPollSchema, pollParamSchema, resolvePollSchema, voteSchema } from "../schemas/poll";
import { tripIdParamSchema } from "../schemas/trip";
import { getMemberTrip } from "./trips";

type MemberTrip = Awaited<ReturnType<typeof getMemberTrip>>;

const POLL_RELATIONS = {
  options: { orderBy: [asc(pollOption.position)] },
  votes: true as const,
};

const findPoll = (tripId: string, pollId: string) =>
  db.query.poll.findFirst({
    where: and(eq(poll.id, pollId), eq(poll.tripId, tripId)),
    with: POLL_RELATIONS,
  });

type PollWithVotes = NonNullable<Awaited<ReturnType<typeof findPoll>>>;

const toPollResponse = (record: PollWithVotes, userId: string) => ({
  id: record.id,
  question: record.question,
  status: getPollStatus(record),
  createdBy: record.createdBy,
  closesAt: record.closesAt,
  createdAt: record.createdAt,
  resolvedAt: record.resolvedAt,
  winningOptionId: record.winningOptionId,
  planDate: record.planDate,
  myOptionId: record.votes.find((vote) => vote.userId === userId)?.optionId ?? null,
  voterCount: record.votes.length,
  options: record.options.map((option) => {
    const voterIds = record.votes
      .filter((vote) => vote.optionId === option.id)
      .map((vote) => vote.userId);
    return {
      id: option.id,
      name: option.name,
      description: option.description,
      voteCount: voterIds.length,
      voterIds,
    };
  }),
});

const getPoll = async (tripId: string, pollId: string) => {
  const record = await findPoll(tripId, pollId);
  if (!record) {
    throw new ApiError(404, "poll_not_found", "Poll not found");
  }
  return record;
};

const getRefreshedPoll = async (tripId: string, pollId: string, userId: string) =>
  toPollResponse(await getPoll(tripId, pollId), userId);

const assertCanManagePoll = (record: MemberTrip, target: PollWithVotes, userId: string) => {
  if (
    target.createdBy !== userId &&
    record.members.find((member) => member.userId === userId)?.role !== "organizer"
  ) {
    throw new ApiError(403, "forbidden", "Only the poll author or an organizer can manage it");
  }
};

const assertOpenPoll = (target: PollWithVotes) => {
  if (getPollStatus(target) !== "open") {
    throw new ApiError(409, "poll_closed", "Voting in this poll has ended");
  }
};

const assertPollOption = (target: PollWithVotes, optionId: string) => {
  if (!target.options.some((option) => option.id === optionId)) {
    throw new ApiError(400, "invalid_option", "Option does not belong to this poll");
  }
};

const assertPlanDateWithinTrip = (record: MemberTrip, planDate: string | null) => {
  if (planDate && (planDate < record.startDate || planDate > record.endDate)) {
    throw new ApiError(400, "date_out_of_range", "Date must be within the trip dates");
  }
};

const getTopOptionId = (target: PollWithVotes) => {
  const voteCounts = target.options.map((option) => ({
    optionId: option.id,
    voteCount: target.votes.filter((vote) => vote.optionId === option.id).length,
  }));
  const topCount = Math.max(...voteCounts.map((entry) => entry.voteCount));
  const leaders = voteCounts.filter((entry) => entry.voteCount === topCount);
  const [leader] = leaders;
  if (topCount === 0 || leaders.length > 1 || !leader) {
    throw new ApiError(409, "poll_tied", "No single leading option, pass optionId to resolve");
  }
  return leader.optionId;
};

export const polls = new Hono<AppEnv>()
  .use(requireAuth)
  .get("/:id/polls", validate("param", tripIdParamSchema), async (c) => {
    const { id } = c.req.valid("param");
    const userId = c.get("user").id;
    await getMemberTrip(id, userId);
    const records = await db.query.poll.findMany({
      where: eq(poll.tripId, id),
      with: POLL_RELATIONS,
      orderBy: [desc(poll.createdAt)],
    });
    return c.json(records.map((record) => toPollResponse(record, userId)));
  })
  .post(
    "/:id/polls",
    validate("param", tripIdParamSchema),
    validate("json", createPollSchema),
    async (c) => {
      const { id } = c.req.valid("param");
      const userId = c.get("user").id;
      await getMemberTrip(id, userId);
      const { options, ...fields } = c.req.valid("json");
      const pollId = await db.transaction(async (tx) => {
        const created = getFirstRow(
          await tx
            .insert(poll)
            .values({ ...fields, tripId: id, createdBy: userId })
            .returning({ id: poll.id }),
        );
        await tx
          .insert(pollOption)
          .values(options.map((option, position) => ({ ...option, pollId: created.id, position })));
        return created.id;
      });
      return c.json(await getRefreshedPoll(id, pollId, userId), 201);
    },
  )
  .get("/:id/polls/:pollId", validate("param", pollParamSchema), async (c) => {
    const { id, pollId } = c.req.valid("param");
    const userId = c.get("user").id;
    await getMemberTrip(id, userId);
    return c.json(await getRefreshedPoll(id, pollId, userId));
  })
  .delete("/:id/polls/:pollId", validate("param", pollParamSchema), async (c) => {
    const { id, pollId } = c.req.valid("param");
    const userId = c.get("user").id;
    const record = await getMemberTrip(id, userId);
    assertCanManagePoll(record, await getPoll(id, pollId), userId);
    await db.delete(poll).where(eq(poll.id, pollId));
    return c.body(null, 204);
  })
  .put(
    "/:id/polls/:pollId/vote",
    validate("param", pollParamSchema),
    validate("json", voteSchema),
    async (c) => {
      const { id, pollId } = c.req.valid("param");
      const userId = c.get("user").id;
      await getMemberTrip(id, userId);
      const target = await getPoll(id, pollId);
      const { optionId } = c.req.valid("json");
      assertOpenPoll(target);
      assertPollOption(target, optionId);
      await db
        .insert(pollVote)
        .values({ pollId, optionId, userId })
        .onConflictDoUpdate({
          target: [pollVote.pollId, pollVote.userId],
          set: { optionId, createdAt: new Date() },
        });
      return c.json(await getRefreshedPoll(id, pollId, userId));
    },
  )
  .delete("/:id/polls/:pollId/vote", validate("param", pollParamSchema), async (c) => {
    const { id, pollId } = c.req.valid("param");
    const userId = c.get("user").id;
    await getMemberTrip(id, userId);
    assertOpenPoll(await getPoll(id, pollId));
    await db.delete(pollVote).where(and(eq(pollVote.pollId, pollId), eq(pollVote.userId, userId)));
    return c.json(await getRefreshedPoll(id, pollId, userId));
  })
  .post(
    "/:id/polls/:pollId/resolve",
    validate("param", pollParamSchema),
    validate("json", resolvePollSchema),
    async (c) => {
      const { id, pollId } = c.req.valid("param");
      const userId = c.get("user").id;
      const record = await getMemberTrip(id, userId);
      const target = await getPoll(id, pollId);
      assertCanManagePoll(record, target, userId);
      if (target.resolvedAt) {
        throw new ApiError(409, "poll_already_resolved", "Poll is already resolved");
      }
      const { optionId, planDate } = c.req.valid("json");
      if (optionId) {
        assertPollOption(target, optionId);
      }
      assertPlanDateWithinTrip(record, planDate);
      await db
        .update(poll)
        .set({
          resolvedAt: new Date(),
          winningOptionId: optionId ?? getTopOptionId(target),
          planDate,
        })
        .where(eq(poll.id, pollId));
      return c.json(await getRefreshedPoll(id, pollId, userId));
    },
  );
