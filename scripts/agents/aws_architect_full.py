from mcp import stdio_client, StdioServerParameters
from strands import Agent, tool
from strands.models.openai import OpenAIModel
from strands.tools.mcp import MCPClient

# Custom AWS architecture tools
@tool
def design_vpc(cidr_block: str, availability_zones: int = 2) -> str:
    """Design a VPC architecture with subnets across availability zones.

    Args:
        cidr_block: The CIDR block for the VPC (e.g., "10.0.0.0/16")
        availability_zones: Number of availability zones to use (default: 2)
    """
    return f"""
VPC Architecture Design:
- VPC CIDR: {cidr_block}
- Availability Zones: {availability_zones}
- Public Subnets: {availability_zones} (one per AZ)
- Private Subnets: {availability_zones} (one per AZ)
- NAT Gateways: {availability_zones} (one per AZ for high availability)
- Internet Gateway: 1
- Route Tables: 2 (public and private)

Recommended subnet allocation:
{chr(10).join([f"  AZ-{i+1} Public: {cidr_block.split('/')[0].rsplit('.', 1)[0]}.{i*16}.0/20" for i in range(availability_zones)])}
{chr(10).join([f"  AZ-{i+1} Private: {cidr_block.split('/')[0].rsplit('.', 1)[0]}.{i*16+128}.0/20" for i in range(availability_zones)])}
"""

@tool
def recommend_compute(workload_type: str, expected_traffic: str) -> str:
    """Recommend compute services based on workload characteristics.

    Args:
        workload_type: Type of workload (e.g., "web", "batch", "microservices", "ml")
        expected_traffic: Expected traffic pattern (e.g., "steady", "variable", "spiky", "unpredictable")
    """
    recommendations = {
        "web": {
            "steady": "EC2 with Auto Scaling Group + Application Load Balancer",
            "variable": "ECS Fargate with Application Load Balancer",
            "spiky": "Lambda with API Gateway",
            "unpredictable": "ECS Fargate with Auto Scaling"
        },
        "batch": {
            "steady": "EC2 Spot Instances with AWS Batch",
            "variable": "AWS Batch with Fargate",
            "spiky": "Lambda or Step Functions",
            "unpredictable": "AWS Batch with mixed instance types"
        },
        "microservices": {
            "steady": "EKS with managed node groups",
            "variable": "ECS Fargate",
            "spiky": "Lambda with API Gateway",
            "unpredictable": "EKS with Karpenter autoscaling"
        },
        "ml": {
            "steady": "SageMaker endpoints with auto-scaling",
            "variable": "SageMaker Serverless Inference",
            "spiky": "Lambda with SageMaker async inference",
            "unpredictable": "SageMaker with auto-scaling"
        }
    }

    recommendation = recommendations.get(workload_type.lower(), {}).get(expected_traffic.lower(),
                                                                         "Please provide valid workload_type and expected_traffic")

    return f"Recommended compute service for {workload_type} workload with {expected_traffic} traffic: {recommendation}"

@tool
def design_database(data_type: str, scale: str, consistency_requirement: str = "strong") -> str:
    """Recommend database services based on data characteristics.

    Args:
        data_type: Type of data (e.g., "relational", "document", "key-value", "graph", "timeseries")
        scale: Expected scale (e.g., "small", "medium", "large", "massive")
        consistency_requirement: Consistency requirement (e.g., "strong", "eventual")
    """
    recommendations = {
        "relational": {
            "small": "RDS (MySQL/PostgreSQL) - Single AZ",
            "medium": "RDS (MySQL/PostgreSQL) - Multi-AZ",
            "large": "Aurora PostgreSQL with read replicas",
            "massive": "Aurora PostgreSQL Global Database"
        },
        "document": {
            "small": "DocumentDB (single instance)",
            "medium": "DocumentDB (replica set)",
            "large": "DocumentDB (sharded cluster)",
            "massive": "DynamoDB with on-demand capacity"
        },
        "key-value": {
            "small": "ElastiCache Redis (single node)",
            "medium": "ElastiCache Redis (cluster mode disabled)",
            "large": "ElastiCache Redis (cluster mode enabled)",
            "massive": "DynamoDB with DAX"
        },
        "graph": {
            "small": "Neptune (single instance)",
            "medium": "Neptune (with read replicas)",
            "large": "Neptune (multi-region)",
            "massive": "Neptune (global database)"
        },
        "timeseries": {
            "small": "RDS PostgreSQL with TimescaleDB",
            "medium": "Timestream",
            "large": "Timestream with data tiering",
            "massive": "Timestream + S3 for long-term storage"
        }
    }

    db_service = recommendations.get(data_type.lower(), {}).get(scale.lower(), "Invalid data_type or scale")

    consistency_note = ""
    if consistency_requirement.lower() == "eventual" and data_type.lower() in ["document", "key-value"]:
        consistency_note = "\nNote: Consider DynamoDB for eventual consistency requirements with global tables for multi-region."

    return f"Recommended database: {db_service}{consistency_note}"

@tool
def security_best_practices(resource_type: str) -> str:
    """Provide security best practices for AWS resources.

    Args:
        resource_type: Type of AWS resource (e.g., "s3", "ec2", "rds", "lambda", "vpc")
    """
    practices = {
        "s3": """
S3 Security Best Practices:
1. Enable bucket encryption (SSE-S3 or SSE-KMS)
2. Block public access unless explicitly needed
3. Enable versioning for data protection
4. Use bucket policies with least privilege
5. Enable access logging
6. Enable MFA Delete for critical buckets
7. Use VPC endpoints for private access
""",
        "ec2": """
EC2 Security Best Practices:
1. Use Systems Manager Session Manager instead of SSH
2. Keep AMIs and software up to date
3. Use security groups with least privilege (no 0.0.0.0/0 for SSH)
4. Enable detailed monitoring
5. Use IAM roles instead of access keys
6. Encrypt EBS volumes
7. Use AWS Systems Manager for patch management
""",
        "rds": """
RDS Security Best Practices:
1. Enable encryption at rest
2. Use SSL/TLS for connections
3. Place in private subnets
4. Use security groups to restrict access
5. Enable automated backups
6. Enable Multi-AZ for production
7. Use IAM database authentication
8. Enable Enhanced Monitoring
"""
    }

    return practices.get(resource_type.lower(), f"Security best practices not available for {resource_type}")


# Configure model
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

# Create MCP client
aws_knowledge_client = MCPClient(
    lambda: stdio_client(
        StdioServerParameters(
            command="uvx",
            args=["fastmcp", "run", "https://knowledge-mcp.global.api.aws"]
        )
    ),
    prefix="aws"
)

# Combine custom tools with MCP tools
agent = Agent(
    name="AWSArchitect",
    system_prompt="""You are an expert AWS Solutions Architect with both custom design tools
and access to AWS documentation. Use your custom tools for architecture design and MCP tools
for documentation lookup.""",
    model=model,
    tools=[
        design_vpc,
        recommend_compute,
        design_database,
        security_best_practices,
        aws_knowledge_client  # MCP tools loaded dynamically
    ]
)


def main():
    print("AWS Solutions Architect Agent (Full Version)")
    print("=" * 60)
    print("Combines custom architecture tools with AWS documentation access")
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
            print("Thinking...")  # Let user know it's processing
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
