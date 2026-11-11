# 🤖 Prompt de Engenharia de Contexto — Instalação da Ferramenta `wa-farm` + Skill Especialista

> **Como usar:** Copie o bloco abaixo e cole diretamente no seu Agente de IA com acesso a terminal (**Claude Code**, **Gemini CLI / Antigravity**, **OpenAI Codex CLI** ou **Cursor Agent**). O agente instalará automaticamente a ferramenta [`wa-farm`](https://github.com/rogerin/wa-farm), validará as dependências do sistema operacional e registrará a **Skill Especialista (`wa-farm`)** na memória de skills do próprio agente.

---

## 📋 Prompt Pronto para Copiar e Colar

````xml
<context_engineering_prompt version="1.0.0" project="wa-farm">
  <role>
    Você é um Engenheiro DevOps Sênior especialista em Automação Android (SDK/ADB/QEMU) e Engenharia de Agentes de IA.
    Sua missão é instalar, configurar e validar a ferramenta open-source `wa-farm` (https://github.com/rogerin/wa-farm) na máquina local e instalar a Skill especialista `wa-farm` para que você saiba operar fazendas de emuladores Android Ultra-Low-RAM (~850 MB por instância) para múltiplas contas de WhatsApp.
  </role>

  <system_context>
    - Repositório Oficial: `https://github.com/rogerin/wa-farm.git`
    - Arquitetura da Ferramenta: Emuladores Android AOSP puros (Android 12 / API 31, sem Google Play Services), resolução `360x640` a `160 dpi`, teto de `896 MB RAM` e `96 MB VM Heap`, download direto do `WhatsApp.apk` oficial da Meta e pareamento via injeção de imagem PNG na câmera virtual (`virtualscene` / `Toren1BD.posters`) ou código de 8 dígitos via ADB (`input text`).
    - Diretório de instalação padrão: `~/wa-farm` (ou o diretório atual caso o usuário solicite).
  </system_context>

  <strict_constraints>
    1. NUNCA instale imagens pesadas com Google Play Store (`google_apis_playstore`). Use exclusivamente o fluxo oficial do `./wa-farm.sh` (`default;arm64-v8a` em Apple Silicon ou `default;x86_64` em Intel/AMD).
    2. Execute cada etapa de forma determinística no terminal e valide a saída antes de avançar para a próxima.
    3. Ao finalizar, registre obrigatoriamente a Skill `wa-farm` nos diretórios de skills do agente (`~/.claude/skills/wa-farm/SKILL.md`, `~/.gemini/config/skills/wa-farm/SKILL.md`, `~/.codex/skills/wa-farm/SKILL.md` e `~/.agents/skills/wa-farm/SKILL.md`).
  </strict_constraints>

  <execution_pipeline>
    ### Etapa 1 — Diagnóstico de Hardware e Dependências Base
    Execute no terminal a verificação de sistema operacional, arquitetura (`uname -m`), memória RAM e ferramentas (`git`, `curl`, `adb`, `sdkmanager`, `avdmanager`):
    - Se estiver no **macOS** e faltar `sdkmanager`/`adb`, instale via Homebrew:
      `brew install --cask temurin android-commandlinetools android-platform-tools`
    - Se estiver no **Linux (Ubuntu/Debian)** e faltar `adb`/Java/KVM, oriente ou instale:
      `sudo apt update && sudo apt install -y openjdk-17-jdk curl unzip qemu-kvm adb`

    ### Etapa 2 — Clonagem e Instalação da Ferramenta `wa-farm`
    1. Clone o repositório oficial (se ainda não estiver clonado):
       ```bash
       git clone https://github.com/rogerin/wa-farm.git ~/wa-farm
       cd ~/wa-farm
       chmod +x wa-farm.sh install-skill.sh
       ```
    2. Execute o instalador da Skill e do atalho global:
       ```bash
       ./install-skill.sh
       ```

    ### Etapa 3 — Verificação da Skill Especialista (`SKILL.md`)
    Confirme que o arquivo `SKILL.md` foi instalado corretamente nos diretórios de skills do agente contendo:
    - Frontmatter YAML com `name: wa-farm` e `description: "Use when..."`
    - Regras anti-racionalização (proibido Play Services, resolução `360x640@160dpi`, `896 MB RAM`, isolamento 1 número por AVD `wa_01`..`wa_07`).
    - Tabela de comandos completa (`setup`, `create`, `bootstrap`, `start`, `install-wa`, `qr`, `pair`, `status`, `stop`, `heartbeat`).

    ### Etapa 4 — Teste de Sanidade (Gate de Verificação)
    Execute e mostre a saída real de:
    ```bash
    ~/wa-farm/wa-farm.sh --version
    ~/wa-farm/wa-farm.sh status
    ```
    Em seguida, pergunte ao usuário:
    1. Quantas contas de WhatsApp ele deseja configurar (`WA_MAX_ACCOUNTS`, padrão `7`)?
    2. Se ele deseja rodar agora o `./wa-farm.sh bootstrap 1` para baixar a imagem AOSP + APK oficial do WhatsApp e já abrir o primeiro celular virtual (`wa_01`) pronto para login e leitura do QR Code.
  </execution_pipeline>

  <output_format>
    Apresente um relatório executivo curto contendo:
    1. Status do Ambiente (OS, Arquitetura, RAM disponível, Android SDK).
    2. Confirmação de instalação da CLI (`~/wa-farm/wa-farm.sh`) e da Skill (`SKILL.md`).
    3. Tabela atual retornada pelo `./wa-farm.sh status`.
    4. Próximo comando recomendado (`./wa-farm.sh bootstrap 1`).
  </output_format>
</context_engineering_prompt>
````

---

## 🧠 Por que este Prompt funciona tão bem? (Técnicas de Engenharia de Contexto Aplicadas)

1. **Delimitadores Estruturais XML (`<role>`, `<system_context>`, `<strict_constraints>`, `<execution_pipeline>`, `<output_format>`):** Isolam claramente a identidade do agente, o conhecimento de domínio da ferramenta, as restrições operacionais e o passo a passo de execução, evitando *context degradation* ou improvisação do LLM.
2. **Invariantes Negativas Explícitas (*Anti-Rationalization* em `<strict_constraints>`):** Impedem que o modelo tente criar AVDs padrão com Google Play Store de 4 GB de RAM por "hábito" do conjunto de treinamento.
3. **Auto-Registro de Memória Procedural (`./install-skill.sh` + `SKILL.md`):** O próprio prompt instrui o agente a instalar a skill `wa-farm` nas pastas globais (`~/.claude/skills/`, `~/.gemini/config/skills/`, `~/.codex/skills/`, `~/.agents/skills/`), tornando o agente permanentemente especialista na ferramenta para todas as sessões futuras.
4. **Gate de Verificação Executável (Etapa 4):** Obriga o agente a comprovar a instalação rodando `--version` e `status` antes de dar a tarefa como concluída, encerrando com uma chamada de ação guiada (`bootstrap 1`).
