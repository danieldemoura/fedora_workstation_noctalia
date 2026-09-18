# 🌙 Fedora Workstation — Noctalia Installer

Instalador interativo que configura automaticamente o ambiente gráfico **Umbriel + Noctalia** no **Fedora Workstation** (44+).

---

## 📦 O que é instalado

| Componente | Descrição |
|:---|:---|
| **Noctalia** | Shell de desktop Wayland — barra superior, notificações, launcher e papel de parede via `wlr-layer-shell` |
| **Umbriel** | Compositor Wayland leve baseado em wlroots (gerencia janelas e atalhos de teclado) |
| **Kitty** | Emulador de terminal padrão, acessível via `Mod + Enter` |
| **Greetd** | Gerenciador de login minimalista para Wayland *(opcional)* |
| **Noctalia Greeter** | Tela de login moderna que substitui o GDM *(opcional)* |

---

## ⚙️ Pré-requisitos

- **Fedora Workstation 44+** (única distro suportada — o script usa `dnf` e o repositório Terra)
- Conexão com a internet
- Executar com seu **usuário normal** (não como `root` / `sudo`)

---

## 🚀 Instalação

Existem **duas formas** de obter e rodar o script:

### Opção 1 — Via `git clone`

Clone o repositório, dê permissão de execução e rode o script:

```bash
git clone https://github.com/danieldemoura/fedora_workstation_noctalia.git
cd fedora_workstation_noctalia
chmod +x install.sh
./install.sh
```

### Opção 2 — Via Gist (download direto com `curl`)

Se você não quer clonar o repositório inteiro, baixe apenas o script diretamente:

```bash
curl -o install.sh https://gist.githubusercontent.com/danieldemoura/b5ad939ff4a324cfa0c0414a0e324832/raw/fedora_workstation_noctalia
chmod +x install.sh
./install.sh
```

> 💡 **Dica:** essa URL (sem hash de commit) sempre baixa a **versão mais recente** do script no Gist.

Ou, em uma linha só (baixa e executa direto):

```bash
bash <(curl -fsSL https://gist.githubusercontent.com/danieldemoura/b5ad939ff4a324cfa0c0414a0e324832/raw/fedora_workstation_noctalia)
```

> ⚠️ **Atenção:** sempre revise scripts antes de executar com `bash <(curl ...)`. Para inspecionar o conteúdo antes, use a opção de download (`curl -o`) acima.

---

## 🧭 Como usar o instalador

O script é **interativo** e guiará você por **3 perguntas** antes de começar:

### Pergunta 1 — Ambiente de instalação

| Opção | Descrição |
|:---:|:---|
| **1** (padrão) | **Máquina Física** — usa aceleração de GPU normalmente |
| **2** | **Máquina Virtual** (VMware / VirtualBox) — aplica contornos para driver de vídeo virtual (`SVGA3D`): renderização por software (`LIBGL_ALWAYS_SOFTWARE=1`) e cursor por software (`hardware_cursor = false`) |

### Pergunta 2 — Nome da sessão

Define o nome exibido na lista de sessões da tela de login. O padrão é **Umbriel**, mas pode ser alterado para **Noctalia** ou qualquer outro nome.

### Pergunta 3 — Noctalia Greeter

| Opção | Descrição |
|:---:|:---|
| **1** (padrão) | **Sim** — instala o Noctalia Greeter e substitui o GDM (que fica desabilitado, não removido) |
| **2** | **Não** — mantém o GDM; você seleciona a sessão Umbriel pela engrenagem ⚙️ na tela de login |

Após confirmar o resumo, o script executa automaticamente todos os passos:
1. Instala Noctalia + Kitty
2. Habilita o repositório Terra
3. Instala o Umbriel (e Greetd + Greeter, se escolhido)
4. Copia o `config.toml` base para `~/.config/umbriel/`
5. Configura o autostart do Noctalia (com ajustes de VM, se aplicável)
6. Ajusta o nome da sessão
7. Configura o Greetd (se Greeter foi escolhido)
8. Desabilita o GDM e habilita o Greetd (se Greeter foi escolhido)

---

## 🔄 Após a instalação

- Se instalou o **Noctalia Greeter**: reinicie o computador com `sudo reboot`. A nova tela de login aparecerá automaticamente.
- Se **manteve o GDM**: faça logout do GNOME, clique no ícone de engrenagem ⚙️ na tela de login, selecione a sessão configurada e entre.

> ⚠️ **Importante:** Não tente rodar o comando `noctalia` dentro do GNOME Terminal ou de uma TTY. Ele só funciona dentro da sessão gráfica do Umbriel.

---

## 🛠️ Troubleshooting

### Tela preta após reiniciar

1. Pressione `Ctrl + Alt + F3` para abrir uma TTY
2. Faça login com seu usuário e senha
3. Verifique os logs:
   ```bash
   journalctl -u greetd -b --no-pager | tail -n 100
   ```

### Voltar para o GDM

Se precisar reverter para a tela de login padrão do GNOME:

```bash
sudo systemctl disable --now greetd
sudo systemctl enable --now gdm
sudo reboot
```

### Cursor invisível na VM

Verifique se `hardware_cursor = false` está definido em `~/.config/umbriel/config.toml`:

```toml
[input.cursor]
hardware_cursor = false
```

### Crash do Noctalia na VM (tela preta / Pipe quebrado)

Verifique se o autostart no `~/.config/umbriel/config.toml` inclui a variável de ambiente:

```toml
[general]
autostart = ["env LIBGL_ALWAYS_SOFTWARE=1 noctalia"]
```

---

## 📂 Arquivos de configuração relevantes

| Arquivo | Descrição |
|:---|:---|
| `~/.config/umbriel/config.toml` | Configuração do compositor Umbriel (atalhos, autostart, cursor) |
| `/etc/greetd/config.toml` | Configuração do Greetd (tela de login) |
| `/usr/share/wayland-sessions/umbriel.desktop` | Arquivo `.desktop` da sessão (define o nome visível) |
| `/usr/share/umbriel/config.toml` | Template original do Umbriel (não editar; é sobrescrito em atualizações) |

---

## 📝 Log da instalação

O script salva automaticamente um log completo de cada execução em:

```
/tmp/noctalia-install-YYYYMMDD-HHMMSS.log
```

---

## 📄 Licença

Consulte o repositório original para informações de licença.
