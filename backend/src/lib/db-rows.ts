export const getFirstRow = <Row>(rows: Row[]) => {
  const [row] = rows;
  if (!row) {
    throw new Error("Expected the query to return a row");
  }
  return row;
};
