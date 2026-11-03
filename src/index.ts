export const handler = async () => {
  console.log("Lambda function started");

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: "CI/CD->Salem, this is a test Lambda function response",
      status: "healthy",
    }),
  };
};
