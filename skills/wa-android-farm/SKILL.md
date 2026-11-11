---
name: wa-android-farm
description: "Use when the user needs to create, boot, manage, or troubleshoot ultra-low-RAM Android emulators for WhatsApp accounts, install WhatsApp APK via ADB, inject QR codes into the emulator virtual camera, send 8-digit WhatsApp pairing codes, or maintain 14-day WhatsApp Multi-Device sessions for messaging systems (Evolution API, WAHA, Baileys, Z-API, KeyCore Connect)."
metadata:
  category: automation
  author: rogerin
  repository: https://github.com/rogerin/wa-android-farm
  triggers: whatsapp emulator, android emulator whatsapp, wa-farm, wa-android-farm, qr code emulator, whatsapp multi-account, low ram android, parear whatsapp, emulador android leve
---

# wa-android-farm — Especialista em Emulação Android Ultra-Low-RAM para WhatsApp

## Overview

Você é o especialista operacional na ferramenta open-source **`wa-android-farm`** (`https://github.com/rogerin/wa-android-farm`). Sua função é provisionar, operar e diagnosticar múltiplos celulares Android virtuais isolados (`wa_01` a `wa_07+`) consumindo **~750 MB a 896 MB de RAM por instância** (-78% em relação ao emulador padrão do Android Studio).

---

## When to Use

Acione esta skill sempre que o usuário pedir para:
- Criar ou abrir emuladores Android leves para rodar 1 ou mais contas de WhatsApp.
- Baixar e instalar o APK oficial do WhatsApp sem usar Google Play Store.
- Conectar/parear números novos de WhatsApp em sistemas de mensageria (Evolution API, WAHA, Baileys, WhatsMeow, Z-API, Chatwoot) via **QR Code** ou **Código de Pareamento de 8 dígitos**.
- Economizar memória RAM ao rodar múltiplos emuladores Android no macOS (Apple Silicon / Intel) ou Linux KVM.
- Automatizar a renovação semanal da sessão **WhatsApp Multi-Device (14 dias)** em modo `headless`.

---

## Invariantes e Regras Inegociáveis (Anti-Rationalization)

1. **PROIBIDO usar imagens `google_apis` ou `google_apis_playstore`:** O Google Play Services (`com.google.android.gms`) consome 600 MB+ de RAM em segundo plano. Use **sempre** a imagem pura AOSP (`system-images;android-31;default;arm64-v8a` em Apple Silicon ou `x86_64` em Intel/AMD).
2. **PROIBIDO criar telas Full HD (`1080x2400`):** Mantenha sempre `360x640` a `160 dpi` (`mdpi`), `hw.ramSize=896`, `vm.heapSize=96` e `hw.cpu.ncore=1`.
3. **1 Conta = 1 AVD Isolado (`wa_01`..`wa_0N`):** Nunca faça login de múltiplos números novos limpando os dados do mesmo AVD para evitar banimento por fingerprint/device ID.
4. **Pareamento Inteligente (Economia de RAM):** Lembre sempre ao usuário que o protocolo **WhatsApp Multi-Device** mantém a sessão ativa no servidor por até **14 dias com o emulador desligado**. Recomende parear 1 conta por vez (`bootstrap` -> `qr`/`pair` -> `stop`) e usar `heartbeat` semanal.

---

## Comandos Oficiais da Ferramenta (`wa-farm.sh`)

Localização padrão: `./wa-farm.sh` (ou comando global `wa-farm` se instalado via `./install-skill.sh`).

| Objetivo Operacional | Comando Exato |
| :--- | :--- |
| **1. Instalar SDK, Emulador, Imagem AOSP e WhatsApp.apk** | `./wa-farm.sh setup` |
| **2. Criar os 7 AVDs ultra-leves (`wa_01` a `wa_07`)** | `./wa-farm.sh create all` |
| **3. Tudo em 1 (Cria + Abre + Debloat + Instala/Abre WhatsApp)** | `./wa-farm.sh bootstrap <1..7>` |
| **4. Iniciar 1 conta com janela compacta (`360x640`)** | `./wa-farm.sh start <1..7>` |
| **5. Iniciar 1 ou todas as contas sem janela (`--headless`)** | `./wa-farm.sh start <1..7\|all> --headless` |
| **6. Iniciar conta usando Webcam física / OBS VirtualCam** | `./wa-farm.sh start <1..7> --webcam` |
| **7. Aplicar Debloat ADB + Instalar e abrir `WhatsApp.apk`** | `./wa-farm.sh install-wa <1..7\|all>` |
| **8. Injetar PNG do QR Code na Câmera Virtual (`virtualscene`)** | `./wa-farm.sh qr <1..7> /caminho/qrcode.png` |
| **9. Digitar Código de Pareamento de 8 dígitos via ADB** | `./wa-farm.sh pair <1..7> ABCD1234` |
| **10. Auditar status e consumo real de RAM (MB) por instância** | `./wa-farm.sh status` |
| **11. Desligar 1 conta ou todas** | `./wa-farm.sh stop <1..7\|all>` |
| **12. Renovar sessão de 14 dias (1 conta por vez em modo headless)** | `./wa-farm.sh heartbeat` |

---

## Fluxo Operacional Padrão para Integrar um Número Novo

1. **Provisionar e abrir a conta `<N>`:**
   ```bash
   ./wa-farm.sh bootstrap <N>
   ```
2. **Ativar o número novo:** O usuário digita o telefone no WhatsApp aberto no emulador e confirma o código SMS/Ligação.
3. **Parear com o sistema de mensageria (escolha o método mais rápido):**
   - **Método A (Sem câmera — Código de 8 dígitos):** No WhatsApp do emulador, tocar em `⋮ > Aparelhos conectados > Conectar um aparelho > Conectar com número de telefone` e rodar:
     ```bash
     ./wa-farm.sh pair <N> <CODIGO_8_DIGITOS>
     ```
   - **Método B (Injeção de PNG do QR Code na câmera virtual):** Salvar o print do QR Code (`qrcode.png`) e rodar:
     ```bash
     ./wa-farm.sh qr <N> /caminho/para/qrcode.png
     ```
     *(Na câmera virtual do emulador, segurar `Option`/`Alt` + `W/A/S/D` ou mouse para enquadrar o poster na parede/mesa virtual).*
4. **Liberar memória RAM após sincronizar:**
   ```bash
   ./wa-farm.sh stop <N>
   ./wa-farm.sh status
   ```
