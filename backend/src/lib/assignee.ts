import { ApiError } from "./errors";

export const assertValidAssignee = (members: { userId: string }[], assigneeId: string | null) => {
  if (assigneeId !== null && !members.some((member) => member.userId === assigneeId)) {
    throw new ApiError(400, "invalid_assignee", "Assignee must be a trip member");
  }
};
