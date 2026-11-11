# Plano Técnico & Operacional — Farm de Emuladores Android Ultra-Low-RAM para 7 Contas de WhatsApp

> **Projeto:** KeyCore Connect — Infraestrutura de Emulação Android e Pareamento Multi-Conta WhatsApp  
> **Data:** `2026-11-10`  
> **Ambiente Alvo:** macOS Apple Silicon (`arm64` / M3 Pro — 18 GB RAM, 11 Cores) ou Linux KVM  
> **Script Executável Oficial:** [`wa-farm.sh`](file:///Users/rogerioalencarfilho/Documents/KeyCore/06_Produtos-e-PD/Produtos/KeyCore-Connect/WhatsApp-Android-Farm/wa-farm.sh)

---

## 1. Problema Operacional e Objetivo

Para integrar **7 números novos de WhatsApp** ao sistema de mensageria sem depender de 7 aparelhos físicos na tomada, precisamos emular celulares Android isolados (`wa_01` a `wa_07`), instalar o WhatsApp oficial, autenticar cada número novo (via SMS/Ligação) e conectar o sistema de mensageria via **QR Code** (ou **Código de Pareamento de 8 dígitos**).

### O Gargalo de Memória (e Como Resolvemos)
Um emulador Android padrão criado pelo Android Studio (com Google Play Store, tela Full HD `1080x2400`, snapshots e áudio ativo) consome entre **3,5 GB e 4,2 GB de RAM por instância**. Rodar 7 instâncias padrão exigiria **~28 GB de RAM**, travando uma máquina de 18 GB.

Com a engenharia de enxugamento aplicada no [`wa-farm.sh`](file:///Users/rogerioalencarfilho/Documents/KeyCore/06_Produtos-e-PD/Produtos/KeyCore-Connect/WhatsApp-Android-Farm/wa-farm.sh), reduzimos o consumo para **~750 MB a 900 MB por instância** através de 7 cortes técnicos:

| Otimização Aplicada | Emulador Padrão (Android Studio) | Perfil KeyCore Ultra-Low-RAM (`wa-farm.sh`) | Economia Real |
| :--- | :--- | :--- | :--- |
| **Imagem de Sistema** | Google Play (`google_apis_playstore`) | **AOSP Puro ARM64 (`android-31;default;arm64-v8a`)** | **-600 MB RAM** (elimina `com.google.android.gms`) |
| **Instalação do WhatsApp** | Via Google Play Store | **APK Oficial Direto da Meta** (`whatsapp.com/android/current/WhatsApp.apk`) | Zero conta Google necessária |
| **Resolução e Densidade** | `1080x2400` (`420 dpi`) | **`360x640` (`160 dpi` mdpi)** | **-90% de VRAM/Framebuffer** |
| **RAM e VM Heap (`config.ini`)** | `2048 MB` RAM / `256 MB` Heap | **`896 MB` RAM / `96 MB` Heap / `1 Core`** | **-1.15 GB RAM** por VM |
| **Snapshots e Boot Anim** | Snapshots em RAM/Disco ativos | **`-no-snapshot -no-boot-anim`** | Elimina picos de I/O e memória |
| **Subsistema de Áudio e Sensores** | Áudio, GPS, Giroscópio ativos | **`-no-audio`, GPS/Sensores desligados** | **-120 MB RAM** + menos threads QEMU |
| **Debloat pós-boot via ADB** | Apps nativos rodando em background | **Desativa animações + congela Calendar, Email, Music, Messaging, Browser** | **-150 MB RAM** dentro do Android |

---

## 2. Arquitetura de Operação para as 7 Contas

```mermaid
flowchart LR
    subgraph Host["Mac Apple Silicon (HVF ARM64) — wa-farm.sh"]
        AVD1["wa_01 (Porta 5554)\nRAM: 896 MB | 360x640"]
        AVD2["wa_02 (Porta 5556)\nRAM: 896 MB | 360x640"]
        AVDDots["... wa_03 a wa_06 ..."]
        AVD7["wa_07 (Porta 5566)\nRAM: 896 MB | 360x640"]
    end

    CDN["CDN Oficial WhatsApp\nWhatsApp.apk"] -->|adb install| Host
    MSG["Sistema de Mensageria\n(QR Code PNG ou Código 8 dígitos)"] -->|wa-farm qr / wa-farm pair| Host
    Host -->|Sessão Multi-Device Ativa\n(14 dias independente)| META["Servidores WhatsApp / Meta"]
```

### Estratégia Inteligente de Uso de RAM (2 Modos no mesmo Script)

1. **Modo 1 — Pareamento Sequencial + Heartbeat Headless (Recomendado | ~900 MB de RAM total):**
   - No protocolo **WhatsApp Multi-Device (Aparelhos Conectados)**, depois que você escaneia o QR Code no sistema de mensageria, **o emulador pode ser desligado**. O sistema de mensageria continua enviando e recebendo mensagens sozinho por até **14 dias**.
   - Para evitar que as 7 contas desconectem após 14 dias de celular desligado, o comando `./wa-farm.sh heartbeat` sobe um emulador por vez em modo invisível (`--headless` / `-no-window`), abre o WhatsApp por 60 segundos para renovar o token com a Meta e o desliga antes de abrir o próximo.
2. **Modo 2 — 7 Emuladores Simultâneos Ultra-Low-RAM (~6,2 GB de RAM total):**
   - Caso precise manter os 7 celulares abertos ao mesmo tempo, suba todos com `./wa-farm.sh start all --headless` (sem janela gráfica Qt/QEMU, economizando ~300 MB extras por instância) ou com janela compacta `360x640`.

---

## 3. Como Funciona a Leitura do QR Code no Emulador

Como o celular está dentro do emulador, existem **duas formas diretas** de conectar ao seu sistema de mensageria:

### Método A — Injeção Direta da Imagem do QR Code na Câmera Virtual (Padrão)
O emulador é configurado com `-camera-back virtualscene`. Quando seu sistema de mensageria exibir o QR Code na tela:
1. Tire um print apenas do QR Code (ou salve a imagem como `qrcode.png`).
2. Rode o comando:
   ```bash
   npm run wa -- qr 1 /caminho/para/qrcode.png
   ```
3. O script injeta o `qrcode.png` diretamente no poster da câmera traseira virtual do emulador `wa_01`. Ao clicar em **"Aparelhos conectados > Conectar um aparelho"** no WhatsApp, a câmera do emulador já enxerga o QR Code na parede virtual (segure `Option/Alt` + mova o mouse ou use `W/A/S/D` se precisar aproximar).

### Método B — Código de Pareamento de 8 Dígitos (Zero Câmera)
1. No WhatsApp do emulador, vá em **Aparelhos conectados > Conectar um aparelho** e toque em **"Conectar com número de telefone"** na parte inferior da tela.
2. Gere o código de 8 dígitos no seu sistema de mensageria e envie direto pelo terminal:
   ```bash
   npm run wa -- pair 1 ABCD1234
   ```

---

## 4. Plano de Execução Passo a Passo (Checklist)

- [ ] **Passo 1 — Instalar Emulador ARM64, Imagem AOSP Pura e APK Oficial do WhatsApp:**
  ```bash
  npm run wa:setup
  ```
  *Verificação:* Baixa `emulator`, `system-images;android-31;default;arm64-v8a` e `06_Produtos-e-PD/Produtos/KeyCore-Connect/WhatsApp-Android-Farm/apk/WhatsApp.apk`.

- [ ] **Passo 2 — Criar os 7 Celulares Virtuais (`wa_01` a `wa_07`) com Perfil Ultra-Low-RAM:**
  ```bash
  npm run wa:create
  ```
  *Verificação:* Cria `~/.android/avd/wa_01.avd` até `wa_07.avd` com `896 MB RAM`, `360x640 (160 dpi)`, `1 CPU Core`, sem áudio e sem snapshots.

- [ ] **Passo 3 — Abrir o Emulador da Conta desejada (ex.: Conta 1):**
  ```bash
  npm run wa -- start 1
  ```
  *Verificação:* Abre `wa_01` na porta `5554` (ou use `npm run wa -- start 1 --headless` para modo sem janela).

- [ ] **Passo 4 — Instalar o WhatsApp e Otimizar o Sistema Android (Debloat + Permissões):**
  ```bash
  npm run wa -- install-wa 1
  ```
  *Verificação:* Instala o `WhatsApp.apk`, desativa animações, congela apps nativos desnecessários, concede permissão de câmera e abre o WhatsApp automaticamente na tela.

- [ ] **Passo 5 — Fazer Login com o Número Novo e Escanear o QR Code do Sistema de Mensageria:**
  - Insira o número novo no WhatsApp da instância `wa_01` e valide o SMS/Ligação.
  - Injete o QR Code do sistema de mensageria na câmera virtual:
    ```bash
    npm run wa -- qr 1 /caminho/para/qrcode.png
    ```
  - Ou envie o código de 8 dígitos:
    ```bash
    npm run wa -- pair 1 CODIGO8D
    ```

- [ ] **Passo 6 — Repetir para as Contas `2` a `7` e Auditar Consumo de Memória:**
  ```bash
  npm run wa:status
  ```
  *Verificação:* Exibe a tabela das 7 contas (`wa_01` a `wa_07`), porta ADB, status e MB de RAM consumidos por cada processo.

---

## 5. Tabela de Mapeamento das 7 Instâncias

| Conta | Nome do AVD | Porta ADB / Console | Serial ADB | RAM Máx. (`config.ini`) | Resolução | Uso Recomendado |
| :---: | :--- | :---: | :--- | :---: | :---: | :--- |
| **#01** | `wa_01` | `5554` | `emulator-5554` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #01 |
| **#02** | `wa_02` | `5556` | `emulator-5556` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #02 |
| **#03** | `wa_03` | `5558` | `emulator-5558` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #03 |
| **#04** | `wa_04` | `5560` | `emulator-5560` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #04 |
| **#05** | `wa_05` | `5562` | `emulator-5562` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #05 |
| **#06** | `wa_06` | `5564` | `emulator-5564` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #06 |
| **#07** | `wa_07` | `5566` | `emulator-5566` | `896 MB` | `360x640` (`160 dpi`) | Número WhatsApp #07 |

---

## 6. Referência Rápida de Comandos (`wa-farm.sh`)

```bash
# 1. Preparar SDK, emulador ARM64 e baixar APK oficial do WhatsApp
npm run wa:setup

# 2. Criar os 7 AVDs ultra-leves (wa_01 a wa_07)
npm run wa:create

# 3. Criar + Iniciar + Instalar WhatsApp + Abrir tela em UM ÚNICO COMANDO (ex: Conta 1)
npm run wa -- bootstrap 1

# 4. Abrir apenas uma conta (ex: wa_01) com janela gráfica ultra-leve
npm run wa -- start 1

# 5. Abrir uma conta usando a Webcam do Mac para ler QR Code físico/externo
npm run wa -- start 1 --webcam

# 6. Abrir todas as 7 contas em background (modo headless = máxima economia de RAM)
npm run wa -- start all --headless

# 7. Injetar print de QR Code (PNG) na câmera virtual da conta 1
npm run wa -- qr 1 ~/Desktop/qrcode.png

# 8. Digitar código de pareamento de 8 dígitos na conta 1
npm run wa -- pair 1 ABCD1234

# 9. Ver status e consumo real de RAM (MB) das 7 contas
npm run wa:status

# 10. Desligar uma conta ou todas
npm run wa -- stop 1
npm run wa:stop-all

# 11. Heartbeat periódico (renova sessão Multi-Device de 14 dias nas 7 contas, 1 por vez)
npm run wa:heartbeat
```

---

## 7. Boas Práticas Operacionais (Prevenção de Banimento em Números Novos)

1. **Isolamento de Hardware por Conta:** Nunca faça login de vários números novos no mesmo AVD apagando dados. Cada AVD (`wa_01` a `wa_07`) mantém seu próprio `android_id` e partição `userdata-qemu.img`.
2. **Janela de Estabilização pós-Ativação:** Após ativar um chip/número novo no emulador, preencha nome de perfil e foto, envie 2 ou 3 mensagens manuais entre os próprios números da operação e aguarde **15 a 30 minutos** antes de escanear o QR Code do sistema de mensageria.
3. **Renovação Semanal (`wa:heartbeat`):** Agende ou execute `npm run wa:heartbeat` uma vez por semana para que cada emulador se conecte por 60 segundos aos servidores da Meta, mantendo os dispositivos conectados ativos indefinidamente sem consumir RAM no dia a dia.
