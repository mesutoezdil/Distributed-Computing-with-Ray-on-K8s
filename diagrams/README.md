# Architecture diagrams

4 Mermaid diagrams covering the full Ray-on-Kubernetes architecture.
Render with any Mermaid-compatible tool, then import to Excalidraw.

| File | What it shows |
|---|---|
| `01-architecture.mmd` | Full static view: all components, layers, and connections |
| `02-rayjob-lifecycle.mmd` | Sequence diagram: job submission to cleanup, including Kueue admission branch |
| `03-object-store-and-task-flow.mmd` | How tasks, ObjectRefs, and the Plasma store interact; when spill happens |
| `04-autoscaling-layers.mmd` | The 3 autoscaling layers (Kueue / Ray / K8s node autoscaler) and why you need all 3 |

## Render locally

```bash
# With npx (no install needed)
npx @mermaid-js/mermaid-cli -i diagrams/01-architecture.mmd -o diagrams/01-architecture.svg

# Or open mermaid.live and paste the file contents
```
