from openai import OpenAI

# Configure OpenAI client to point to LM Studio
client = OpenAI(
    api_key="lm-studio",  # LM Studio doesn't require a real key
    base_url="http://localhost:1234/v1"
)

MODEL_ID = "meta-llama-3.1-8b-instruct"  # Use the actual loaded model identifier
SYSTEM_PROMPT = "You are a helpful AI assistant. Provide clear, concise, and accurate responses."

# Conversation history (limited to prevent context overflow)
conversation_history = []
MAX_HISTORY_MESSAGES = 5  # Keep only last 5 exchanges to stay within context limits

def main():
    print("Strands Agent with LM Studio")
    print("=" * 50)
    print("Make sure LM Studio is running on http://localhost:1234")
    print("Type 'quit' to exit")
    print("=" * 50)

    while True:
        user_input = input("\nYou: ").strip()

        if user_input.lower() == 'quit':
            print("Goodbye!")
            break

        if not user_input:
            continue

        try:
            # Add user message to history
            conversation_history.append({"role": "user", "content": user_input})

            # Limit conversation history to prevent context overflow
            if len(conversation_history) > MAX_HISTORY_MESSAGES * 2:
                # Keep only the most recent messages (user + assistant pairs)
                conversation_history = conversation_history[-MAX_HISTORY_MESSAGES * 2:]

            # Build messages with system prompt and limited history
            messages = [{"role": "system", "content": SYSTEM_PROMPT}] + conversation_history

            # Call LM Studio API directly
            print("Thinking...")  # Let user know it's processing
            response = client.chat.completions.create(
                model=MODEL_ID,
                messages=messages,
                max_tokens=500,  # Reduced to leave room for context
                temperature=0.7
            )
            assistant_message = response.choices[0].message.content
            print(f"\nAssistant: {assistant_message}")

            # Add assistant response to history
            conversation_history.append({"role": "assistant", "content": assistant_message})
        except Exception as e:
            error_msg = str(e)
            print(f"\nError: {error_msg}")
            if "context length" in error_msg.lower() or "context overflow" in error_msg.lower():
                print("\nContext length exceeded. Try:")
                print("1. Reload the model with a larger context length:")
                print("   lms load meta-llama-3.1-8b-instruct --context-length 8192")
                print("2. Or use a model with a larger context window")
                print("3. Or restart the conversation (the script will clear history)")
            else:
                print("Please check that LM Studio is running and a model is loaded.")


if __name__ == "__main__":
    main()
