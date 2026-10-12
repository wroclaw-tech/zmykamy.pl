type LogLevel = "debug" | "info" | "warn" | "error";
type LogContext = Record<string, unknown>;

const getSerializableContext = (context: LogContext) =>
  Object.fromEntries(
    Object.entries(context).map(([key, value]) => [
      key,
      value instanceof Error
        ? { name: value.name, message: value.message, stack: value.stack, cause: value.cause }
        : value,
    ]),
  );

const createLogMethod = (level: LogLevel) => (message: string, context?: LogContext) => {
  const line = `[${new Date().toISOString()}] ${level.toUpperCase().padEnd(5)} ${message}`;
  if (context) {
    console[level](line, JSON.stringify(getSerializableContext(context)));
    return;
  }
  console[level](line);
};

export const logger = {
  debug: createLogMethod("debug"),
  info: createLogMethod("info"),
  warn: createLogMethod("warn"),
  error: createLogMethod("error"),
};
