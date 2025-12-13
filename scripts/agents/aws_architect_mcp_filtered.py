"""
AWS Architect Agent with MCP Tools and Tool Filtering Example

This demonstrates how to filter MCP tools to only use specific ones,
as mentioned in the tutorial's "Best Practices and Tips" section.
"""

from mcp import stdio_client, StdioServerParameters
from strands import Agent
from strands.models.openai import OpenAIModel
from strands.tools.mcp import MCPClient
import re

# Configure OpenAI-compatible model pointing to LM Studio
model = OpenAIModel(
    client_args={
        "api_key": "lm-studio",
        "base_url": "http://localhost:1234/v1",
    },
    model_id="meta-llama-3.1-8b-instruct",  # Use the actual loaded model identifier
    params={
        "max_tokens": 500,  # Reduced from 2000 to speed up inference on limited CPU
        "temperature": 0.7,
    }
)

# Create MCP client with tool filtering
# Only allow search and regional availability tools
aws_knowledge_client = MCPClient(
    lambda: stdio_client(
        StdioServerParameters(
            command="uvx",
            args=["fastmcp", "run", "https://knowledge-mcp.global.api.aws"]
        )
    ),
    prefix="aws",
    tool_filters={
        "allowed": [
            re.compile(r"^search_.*"),  # Allow all search tools
            "get_regional_availability"  # Allow regional availability check
        ]
    }
)

# Create agent with filtered MCP client
agent = Agent(
    name="AWSArchitect",
    system_prompt="""You are an expert AWS Solutions Architect with access to AWS documentation.

Use your tools to:
- Search AWS documentation for current information
- Check service availability in different regions
- Provide architecture recommendations based on AWS best practices
- Always cite your sources from AWS documentation""",
    model=model,
    tools=[aws_knowledge_client]
)


def main():
    print("AWS Solutions Architect Agent (with Filtered MCP Tools)")
    print("=" * 60)
    print("Connected to AWS Knowledge MCP Server (filtered tools only)")
    print("Type 'quit' to exit")
    print("=" * 60)

    while True:
        user_input = input("\nYou: ").strip()

        if user_input.lower() == 'quit':
            print("Goodbye!")
            break

        if not user_input:
            continue

        try:
            print("Thinking... (this may take a moment as I search AWS documentation)")  # Let user know it's processing
            response = agent(user_input)
            print(f"\nAWS Architect: {response}")
        except Exception as e:
            error_msg = str(e)
            print(f"\nError: {error_msg}")

            # Check for context length errors
            if "context length" in error_msg.lower() or "context overflow" in error_msg.lower() or "trying to keep" in error_msg.lower():
                print("\n" + "=" * 60)
                print("CONTEXT LENGTH EXCEEDED")
                print("=" * 60)
                print("\nThe model's context window is too small for MCP tools.")
                print("MCP tools add significant context (tool descriptions, etc.).")
                print("\nSolution: Reload the model with a larger context length:")
                print("\n  lms load meta-llama-3.1-8b-instruct --context-length 8192")
                print("\nOr use a model with a larger default context window.")
                print("=" * 60)
            else:
                import traceback
                traceback.print_exc()
                print("Please try rephrasing your question.")


if __name__ == "__main__":
    main()
