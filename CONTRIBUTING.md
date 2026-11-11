# Contribuindo com o `wa-farm`

Obrigado pelo interesse em contribuir com o **`wa-farm`**!

## Como Contribuir

1. Faça um **Fork** do repositório (`https://github.com/rogerin/wa-farm`).
2. Crie uma branch para sua feature ou correção:
   ```bash
   git checkout -b feat/minha-melhoria
   ```
3. Certifique-se de que o script `wa-farm.sh` continua compatível com Bash (`bash -n wa-farm.sh`) e passa no `shellcheck`:
   ```bash
   bash -n wa-farm.sh
   ./wa-farm.sh --version
   ./wa-farm.sh status
   ```
4. Envie um **Pull Request** detalhando o ganho de memória, performance ou usabilidade.

## Diretrizes de Engenharia

- **Economia de Memória em Primeiro Lugar:** Qualquer nova flag ou configuração deve priorizar redução de RAM, VRAM e CPU.
- **Zero Dependências Pesadas:** Mantenha o núcleo em Bash puro + ferramentas oficiais do Android SDK (`sdkmanager`, `avdmanager`, `emulator`, `adb`).
- **Compatibilidade Multi-Plataforma:** Suporte tanto macOS (`arm64` Apple Silicon / `x86_64`) quanto Linux (`x86_64` KVM / `arm64`).
