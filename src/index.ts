export const handler = async () => {
  console.log("Lambda function started");

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: "Hello from my DevOps portfolio project!",
      status: "healthy",
    }),
  };
};