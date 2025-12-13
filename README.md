# terraform-aws-demo-template

Reusable Terraform template for building AWS infrastructure demos

## AWS Solutions Architect Agent

This repository includes an AWS Solutions Architect Agent setup based on [this guide](https://dunlop.geek.nz/building-an-aws-solutions-architect-agent-with-strands-lm-studio-and-mcp-tools/).

### Quick Start

1. **Run the setup script (installs everything automatically):**

   ```bash
   cd scripts/agents
   ./setup_agent.sh
   ```

   This will:
   - Install Python 3.13
   - Install `uv` (Python package manager)
   - Install Python dependencies (strands-agents, openai, mcp)
   - Install LM Studio automatically
   - Create agent files

2. **Start LM Studio service and load a model:**

   ```bash
   # Start the service
   sudo systemctl start lm-studio

   # Download a model (recommended: Llama 3.1 8B)
   lms get "Llama 3.1 8B Instruct"

   # Load the model with larger context length (required for MCP agents)
   # MCP tools add significant context, so 8192 tokens is recommended
   lms load meta-llama-3.1-8b-instruct --context-length 8192
   ```

3. **Run an agent:**

   ```bash
   cd scripts/agents

   # Basic conversational agent
   python3 strands_agent.py

   # AWS Architect with custom tools
   python3 aws_architect_agent.py

   # AWS Architect with MCP (AWS documentation access)
   python3 aws_architect_mcp.py

   # Full AWS Architect (custom tools + MCP)
   python3 aws_architect_full.py

   # AWS Architect with filtered MCP tools (example)
   python3 aws_architect_mcp_filtered.py
   ```

### Available Agents

- **strands_agent.py**: Basic conversational agent using LM Studio
- **aws_architect_agent.py**: AWS Solutions Architect with custom architecture tools (VPC design, compute recommendations, database recommendations, security best practices)
- **aws_architect_mcp.py**: AWS Solutions Architect with access to AWS documentation via MCP
- **aws_architect_full.py**: Complete AWS Solutions Architect combining custom tools and MCP documentation access
- **aws_architect_mcp_filtered.py**: Example showing how to filter MCP tools to only use specific ones (demonstrates tool filtering best practice)

### Prerequisites

- Linux system (tested on Amazon Linux 2023)
- Internet connection (for downloading dependencies, models, and MCP agents to access AWS documentation)
- Sudo access (for installing system packages and LM Studio)

**Note:** The setup script automatically installs:

- Python 3.13
- `uv` (Python package manager)
- LM Studio (via automated script)
- All required Python dependencies

### EC2 Instance Sizing for LLM Inference

LLM inference is CPU-intensive. For optimal performance with Llama 3.1 8B:

| Instance Type | vCPUs | RAM | Performance | Use Case |
|--------------|-------|-----|-------------|----------|
| `t3a.xlarge` | 4 | 16GB | ⚠️ Minimum | Slow, may timeout |
| `t3a.2xlarge` | 8 | 32GB | ✅ **Recommended** | Good balance (default) |
| `c5.2xlarge` | 8 | 16GB | ✅ Better | Compute-optimized, faster |
| `c5.4xlarge` | 16 | 32GB | ✅✅ Best | Fastest CPU inference |

**Note:** For production workloads, consider GPU instances (`g5.xlarge+`) or AWS Inferentia (`inf2.xlarge+`) for 10-100x better performance.

To change the instance type, set the `instance_type` variable:

```bash
terraform apply -var="instance_type=t3a.2xlarge"
```

### Custom Tools

The AWS Architect agents include custom tools for:

- VPC architecture design
- Compute service recommendations
- Database service recommendations
- Security best practices

### MCP Integration

The MCP-enabled agents connect to AWS's official knowledge MCP server, providing:

- Real-time AWS documentation search
- Service availability checks by region
- Up-to-date AWS service information

For more details, see the [original guide](https://dunlop.geek.nz/building-an-aws-solutions-architect-agent-with-strands-lm-studio-and-mcp-tools/).

### Troubleshooting

#### Context Length Exceeded Error

If you see an error like `"Trying to keep the first X tokens when context overflows"`:

**Problem:** MCP tools add significant context (tool descriptions, etc.), which can exceed the model's default context window (4096 tokens).

**Solution:** Reload the model with a larger context length:

```bash
lms load meta-llama-3.1-8b-instruct --context-length 8192
```

For agents without MCP tools (`strands_agent.py`, `aws_architect_agent.py`), the default 4096 tokens is usually sufficient.

#### Slow or No Response

If the agent appears stuck or very slow:

1. **Check CPU usage:** `htop` - LLM inference is CPU-intensive
2. **Upgrade instance:** See [EC2 Instance Sizing](#ec2-instance-sizing-for-llm-inference) section
3. **Try simpler agent:** Test with `strands_agent.py` first (no tool calling)
4. **Check service:** `sudo systemctl status lm-studio`
