import { handler } from "./index";

async function testLambda() {
  const result = await handler();

  if (result.statusCode !== 200) {
    throw new Error("Expected status code 200");
  }

  const body = JSON.parse(result.body);

  if (body.status !== "healthy") {
    throw new Error("Expected healthy status");
  }

  console.log("PASS: Lambda returned a healthy response");
}

testLambda().catch((error) => {
  console.error("FAIL:", error);
  process.exitCode = 1;
});
