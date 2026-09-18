#!/usr/bin/env bash
#
# install-noctalia.sh  (v6)
#
# Instalador de Umbriel + Noctalia Shell (+ opcionalmente Noctalia Greeter)
# para Fedora Workstation, baseado no guia validado pelo autor.
#
# Uso:
#   chmod +x install-noctalia.sh
#   ./install-noctalia.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# cores / helpers
# ---------------------------------------------------------------------------
C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[1;31m'
C_BLUE='\033[1;34m'; C_CYAN='\033[1;36m'; C_MAGENTA='\033[1;35m'

log()  { echo -e "${C_BLUE}[*]${C_RESET} $*"; }
ok()   { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
err()  { echo -e "${C_RED}[ERRO]${C_RESET} $*" >&2; }
step() { echo -e "\n${C_BOLD}${C_CYAN}==> $*${C_RESET}"; }

# pcat: como "cat <<EOF", mas interpreta corretamente os códigos de cor ANSI.
# Uso: pcat <<'EOF' ... EOF   (sempre com aspas em 'EOF' para não expandir aqui,
# a expansão de variável acontece dentro da função via eval-safe read)
pcat() {
    local content
    content="$(cat)"
    printf '%b\n' "$content"
}

LOG_FILE="/tmp/noctalia-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

trap 'err "O script parou na linha $LINENO. Log completo em: $LOG_FILE"' ERR

DNF="sudo dnf -y --setopt=assumeyes=True"

if [[ $EUID -eq 0 ]]; then
    err "Não rode como root/sudo direto. Rode como seu usuário normal."
    exit 1
fi
if ! command -v dnf >/dev/null 2>&1; then
    err "dnf não encontrado — este script funciona apenas em Fedora."
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# TELA DE BOAS-VINDAS
# ---------------------------------------------------------------------------
clear
pcat <<EOF
${C_BOLD}${C_MAGENTA}╔══════════════════════════════════════════════════════════════════╗
║           Instalador — Umbriel + Noctalia (Fedora)                 ║
╚══════════════════════════════════════════════════════════════════╝${C_RESET}

Este script instala e configura um ambiente gráfico Wayland completo
baseado em:

  ${C_BOLD}Umbriel${C_RESET}   — compositor Wayland leve (baseado em wlroots)
  ${C_BOLD}Noctalia${C_RESET}  — shell de desktop (barra, notificações, launcher,
              papel de parede) via protocolo wlr-layer-shell
  ${C_BOLD}Kitty${C_RESET}     — terminal padrão (atalho Mod+Enter no Umbriel)

${C_BOLD}Compatibilidade:${C_RESET} testado em ${C_BOLD}Fedora Workstation${C_RESET} (44+). Não é
indicado para outras distribuições — os nomes de pacote e repositórios
usados aqui (dnf, repositório Terra) são específicos do Fedora.

${C_BOLD}O que será instalado:${C_RESET}
  ${C_GREEN}✓${C_RESET} noctalia            (shell de desktop)
  ${C_GREEN}✓${C_RESET} kitty               (terminal)
  ${C_GREEN}✓${C_RESET} terra-release       (repositório comunitário Terra)
  ${C_GREEN}✓${C_RESET} umbriel-nightly     (compositor Wayland)
  ${C_GREEN}✓${C_RESET} greetd + noctalia-greeter   ${C_DIM}(opcional — você escolhe já já)${C_RESET}

Nada é removido do sistema. Se você optar por instalar o Noctalia
Greeter, o GDM é apenas ${C_BOLD}desabilitado${C_RESET} (não desinstalado), então dá
para voltar facilmente se precisar.

EOF
read -r -p "$(echo -e "${C_YELLOW}Pressione Enter para começar (ou Ctrl+C para cancelar)...${C_RESET}")" _

# ---------------------------------------------------------------------------
# PERGUNTA 1 — Ambiente
# ---------------------------------------------------------------------------
step "1 de 3 — Ambiente de instalação"
pcat <<EOF
  ${C_BOLD}1)${C_RESET} Máquina física ${C_DIM}(padrão)${C_RESET}
  ${C_BOLD}2)${C_RESET} Máquina virtual ${C_DIM}(VMware / VirtualBox)${C_RESET}

  ${C_DIM}Na VM, o driver de vídeo virtual (SVGA3D) quebra a renderização
  por hardware do Wayland. Escolher a opção 2 aplica automaticamente
  os contornos necessários (renderização por software e cursor por
  software) tanto no Umbriel quanto no Noctalia Greeter.${C_RESET}

EOF
read -r -p "$(echo -e "${C_YELLOW}Opção [1]: ${C_RESET}")" INSTALL_MODE
INSTALL_MODE="${INSTALL_MODE:-1}"
if [[ "$INSTALL_MODE" != "1" && "$INSTALL_MODE" != "2" ]]; then
    warn "Opção inválida ('$INSTALL_MODE') — usando o padrão: 1 (Máquina física)."
    INSTALL_MODE="1"
fi
if [[ "$INSTALL_MODE" == "2" ]]; then
    ok "Ambiente: Máquina Virtual"
else
    ok "Ambiente: Máquina Física"
fi

# ---------------------------------------------------------------------------
# PERGUNTA 2 — Nome da sessão
# ---------------------------------------------------------------------------
step "2 de 3 — Nome da sessão na tela de login"
pcat <<EOF
  O nome padrão que aparece na lista de sessões é ${C_BOLD}Umbriel${C_RESET}.
  Você pode digitar outro nome (ex: "Noctalia") ou apertar Enter para
  manter o padrão.

EOF
read -r -p "$(echo -e "${C_YELLOW}Nome da sessão [Umbriel]: ${C_RESET}")" SESSION_NAME
SESSION_NAME="${SESSION_NAME:-Umbriel}"
ok "Nome da sessão: $SESSION_NAME"

# ---------------------------------------------------------------------------
# PERGUNTA 3 — Noctalia Greeter
# ---------------------------------------------------------------------------
step "3 de 3 — Tela de login (Noctalia Greeter)"
pcat <<EOF
  Instalar o ${C_BOLD}Noctalia Greeter${C_RESET} substitui o ${C_BOLD}GDM${C_RESET} (tela de login
  padrão do GNOME) pela tela de login do Noctalia. O GDM não é
  removido, só desabilitado.

  ${C_BOLD}1)${C_RESET} Sim, instalar o Noctalia Greeter ${C_DIM}(padrão)${C_RESET}
  ${C_BOLD}2)${C_RESET} Não, manter o GDM e escolher a sessão Umbriel manualmente
     ${C_DIM}(engrenagem na tela de login do GDM)${C_RESET}

EOF
read -r -p "$(echo -e "${C_YELLOW}Opção [1]: ${C_RESET}")" GREETER_CHOICE
GREETER_CHOICE="${GREETER_CHOICE:-1}"
if [[ "$GREETER_CHOICE" != "1" && "$GREETER_CHOICE" != "2" ]]; then
    warn "Opção inválida ('$GREETER_CHOICE') — usando o padrão: 1 (instalar o Greeter)."
    GREETER_CHOICE="1"
fi
if [[ "$GREETER_CHOICE" == "1" ]]; then
    INSTALL_GREETER=true
    ok "Noctalia Greeter: será instalado (GDM será substituído)."
else
    INSTALL_GREETER=false
    ok "Noctalia Greeter: não será instalado (GDM permanece ativo)."
fi

# ---------------------------------------------------------------------------
# resumo antes de agir
# ---------------------------------------------------------------------------
step "Resumo"
pcat <<EOF
  Ambiente:          $([[ "$INSTALL_MODE" == "2" ]] && echo "Máquina Virtual" || echo "Máquina Física")
  Nome da sessão:    $SESSION_NAME
  Noctalia Greeter:  $([[ "$INSTALL_GREETER" == "true" ]] && echo "Sim (substitui o GDM)" || echo "Não")

EOF
read -r -p "$(echo -e "${C_YELLOW}Confirma e inicia a instalação? [S/n]: ${C_RESET}")" CONFIRM
CONFIRM="${CONFIRM:-s}"
if [[ ! "$CONFIRM" =~ ^([sS]|[yY])$ ]]; then
    log "Cancelado pelo usuário."
    exit 0
fi

log "Log desta execução: $LOG_FILE"

# ---------------------------------------------------------------------------
# PASSO 1 — Noctalia + Kitty
# ---------------------------------------------------------------------------
step "Passo 1 — Instalando Noctalia e Kitty"
if pkg_installed noctalia; then
    ok "Noctalia já instalado."
else
    $DNF install noctalia kitty
    ok "Noctalia e Kitty instalados."
fi
if ! pkg_installed kitty; then
    $DNF install kitty
    ok "Kitty instalado."
fi

# ---------------------------------------------------------------------------
# PASSO 2 — Repositório Terra
# ---------------------------------------------------------------------------
step "Passo 2 — Habilitando o repositório Terra"
if pkg_installed terra-release; then
    ok "Terra já habilitado."
else
    sudo dnf install -y --nogpgcheck --repofrompath \
        'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys
    ok "Terra habilitado."
fi
$DNF makecache

# ---------------------------------------------------------------------------
# PASSO 3 — Umbriel (+ Greetd/Greeter se escolhido)
# ---------------------------------------------------------------------------
step "Passo 3 — Instalando o Umbriel$([[ "$INSTALL_GREETER" == "true" ]] && echo ", greetd e noctalia-greeter")"
if [[ "$INSTALL_GREETER" == "true" ]]; then
    PKGS="umbriel-nightly greetd noctalia-greeter"
else
    PKGS="umbriel-nightly"
fi
# instala só o que falta
for p in $PKGS; do
    if pkg_installed "$p"; then
        ok "$p já instalado."
    else
        $DNF install "$p"
        ok "$p instalado."
    fi
done

# ---------------------------------------------------------------------------
# PASSO 4 — Copiar config.toml base do Umbriel
# ---------------------------------------------------------------------------
step "Passo 4 — Copiando o config.toml base do Umbriel"

UMBRIEL_CFG_DIR="$REAL_HOME/.config/umbriel"
UMBRIEL_CFG="$UMBRIEL_CFG_DIR/config.toml"
TEMPLATE="/usr/share/umbriel/config.toml"

sudo -u "$REAL_USER" mkdir -p "$UMBRIEL_CFG_DIR"

if [[ -f "$UMBRIEL_CFG" ]]; then
    cp "$UMBRIEL_CFG" "${UMBRIEL_CFG}.bak.$(date +%s)"
    log "Já existia um config.toml seu — backup feito."
fi

if [[ -f "$TEMPLATE" ]]; then
    sudo -u "$REAL_USER" cp "$TEMPLATE" "$UMBRIEL_CFG"
    ok "Template copiado de $TEMPLATE para $UMBRIEL_CFG."
else
    err "Não encontrei o template em $TEMPLATE (rpm -ql umbriel-nightly | grep config.toml para checar)."
    exit 1
fi

# ---------------------------------------------------------------------------
# PASSO 5 — Configurar autostart + ajustes de VM no Umbriel
# ---------------------------------------------------------------------------
step "Passo 5 — Configurando o autostart do Noctalia no Umbriel"

if [[ "$INSTALL_MODE" == "2" ]]; then
    AUTOSTART_LINE='autostart = ["env LIBGL_ALWAYS_SOFTWARE=1 noctalia"]'
else
    AUTOSTART_LINE='autostart = ["noctalia"]'
fi

if grep -q '^\[general\]' "$UMBRIEL_CFG"; then
    if grep -qE '^\s*autostart\s*=' "$UMBRIEL_CFG"; then
        sudo -u "$REAL_USER" sed -i -E "s|^\s*autostart\s*=.*|$AUTOSTART_LINE|" "$UMBRIEL_CFG"
    else
        sudo -u "$REAL_USER" sed -i "/^\[general\]/a $AUTOSTART_LINE" "$UMBRIEL_CFG"
    fi
else
    { echo ""; echo "[general]"; echo "$AUTOSTART_LINE"; } | sudo -u "$REAL_USER" tee -a "$UMBRIEL_CFG" >/dev/null
fi
ok "autostart configurado: $AUTOSTART_LINE"

if [[ "$INSTALL_MODE" == "2" ]]; then
    if grep -qE '^\s*hardware_cursor\s*=' "$UMBRIEL_CFG"; then
        sudo -u "$REAL_USER" sed -i -E 's|^\s*hardware_cursor\s*=.*|hardware_cursor = false|' "$UMBRIEL_CFG"
    elif grep -q '^\[input\.cursor\]' "$UMBRIEL_CFG"; then
        sudo -u "$REAL_USER" sed -i "/^\[input\.cursor\]/a hardware_cursor = false" "$UMBRIEL_CFG"
    else
        { echo ""; echo "[input.cursor]"; echo "hardware_cursor = false"; } | sudo -u "$REAL_USER" tee -a "$UMBRIEL_CFG" >/dev/null
    fi
    ok "hardware_cursor = false (necessário em VM)."
fi

sudo chown -R "$REAL_USER":"$REAL_USER" "$UMBRIEL_CFG_DIR"

# ---------------------------------------------------------------------------
# PASSO 6 — Nome da sessão
# ---------------------------------------------------------------------------
step "Passo 6 — Ajustando o nome da sessão para \"$SESSION_NAME\""

SESSION_DESKTOP="/usr/share/wayland-sessions/umbriel.desktop"
if [[ -f "$SESSION_DESKTOP" ]]; then
    sudo cp "$SESSION_DESKTOP" "${SESSION_DESKTOP}.bak.$(date +%s)"
    if grep -qE '^Name=' "$SESSION_DESKTOP"; then
        sudo sed -i -E "s|^Name=.*|Name=$SESSION_NAME|" "$SESSION_DESKTOP"
    else
        sudo sed -i "/^\[Desktop Entry\]/a Name=$SESSION_NAME" "$SESSION_DESKTOP"
    fi
    ok "Sessão renomeada para \"$SESSION_NAME\" em $SESSION_DESKTOP."
else
    warn "Não encontrei $SESSION_DESKTOP — pulando renomeação (listando o que existe):"
    ls -1 /usr/share/wayland-sessions/ 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# PASSO 7 — Configurar greetd + Noctalia Greeter (se escolhido)
# ---------------------------------------------------------------------------
if [[ "$INSTALL_GREETER" == "true" ]]; then
    step "Passo 7 — Configurando o Noctalia Greeter no greetd"

    if ! id greetd >/dev/null 2>&1; then
        err "Usuário de sistema 'greetd' não existe mesmo após instalar o pacote greetd. Abortando antes de mexer no GDM."
        exit 1
    fi

    GREETD_CONF="/etc/greetd/config.toml"
    sudo mkdir -p /etc/greetd
    if [[ -f "$GREETD_CONF" ]]; then
        sudo cp "$GREETD_CONF" "${GREETD_CONF}.bak.$(date +%s)"
        log "Backup do config.toml antigo do greetd feito."
    fi

    if [[ "$INSTALL_MODE" == "2" ]]; then
        GREETD_COMMAND="env LIBGL_ALWAYS_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 /usr/bin/noctalia-greeter-session"
    else
        GREETD_COMMAND="/usr/bin/noctalia-greeter-session"
    fi

    sudo tee "$GREETD_CONF" >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "$GREETD_COMMAND"
user = "greetd"
EOF
    ok "Arquivo $GREETD_CONF escrito (user = \"greetd\", sem linhas duplicadas de agreety)."

    step "Passo 8 — Substituindo o GDM pelo greetd"
    if systemctl is-enabled gdm.service >/dev/null 2>&1 || systemctl is-active gdm.service >/dev/null 2>&1; then
        sudo systemctl disable gdm
        ok "GDM desabilitado (continua instalado)."
    else
        log "GDM não estava ativo/habilitado — nada a desabilitar."
    fi
    sudo systemctl enable greetd
    ok "greetd habilitado para o próximo boot."
else
    log "Noctalia Greeter não selecionado — GDM permanece como tela de login."
fi

# ---------------------------------------------------------------------------
# RESUMO FINAL
# ---------------------------------------------------------------------------
step "Resumo final"

pcat <<EOF

${C_GREEN}${C_BOLD}Instalação concluída.${C_RESET}

  Ambiente:          $([[ "$INSTALL_MODE" == "2" ]] && echo "Máquina Virtual" || echo "Máquina Física")
  Nome da sessão:    $SESSION_NAME
  Noctalia Greeter:  $([[ "$INSTALL_GREETER" == "true" ]] && echo "Instalado (substitui o GDM)" || echo "Não instalado")

  Noctalia:          $(rpm -q noctalia 2>/dev/null)
  Kitty:             $(rpm -q kitty 2>/dev/null)
  Umbriel:           $(rpm -q umbriel-nightly 2>/dev/null || rpm -q umbriel 2>/dev/null)
  Config Umbriel:    $UMBRIEL_CFG
EOF

if [[ "$INSTALL_GREETER" == "true" ]]; then
pcat <<EOF
  Noctalia Greeter:  $(rpm -q noctalia-greeter 2>/dev/null)
  Config greetd:     /etc/greetd/config.toml

${C_BOLD}Próximo passo:${C_RESET} reinicie para ver a nova tela de login:
  sudo reboot

${C_YELLOW}${C_BOLD}Se algo der errado e a tela ficar preta após reiniciar:${C_RESET}
  1) Ctrl+Alt+F3 para ir a uma TTY, faça login com seu usuário/senha.
  2) journalctl -u greetd -b --no-pager | tail -n 100
  3) Para voltar ao GDM:
       sudo systemctl disable --now greetd
       sudo systemctl enable --now gdm
       sudo reboot
EOF
else
pcat <<EOF

${C_BOLD}Como entrar na sessão $SESSION_NAME:${C_RESET}
  1) Faça logout da sessão atual (GNOME).
  2) Na tela de login do GDM, clique no seu usuário.
  3) Clique no ícone de engrenagem (⚙️) perto do campo de senha.
  4) Escolha a sessão "$SESSION_NAME".
  5) Digite sua senha e entre.
EOF
fi

pcat <<EOF

${C_YELLOW}Lembrete:${C_RESET} não teste o comando 'noctalia' dentro do GNOME Terminal
ou de uma TTY — ele só funciona de dentro da sessão gráfica do Umbriel.

Log completo desta execução: $LOG_FILE

EOF