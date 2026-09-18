# Guia de Instalação: Umbriel + Noctalia + Noctalia Greeter no Fedora Workstation

Este guia documenta o passo a passo completo para instalação e configuração do ambiente gráfico composto pelo compositor Wayland **Umbriel**, pela shell de desktop **Noctalia** e pela tela de login **Noctalia Greeter** (via **Greetd**).

* A **Seção 1** cobre a instalação padrão para **Máquinas Físicas (Bare Metal)**.
* A **Seção 2** aborda os ajustes específicos para **Máquinas Virtuais (VMware / VirtualBox)**, detalhando os erros enfrentados e como contorná-los.

---

## 📌 Visão Geral dos Componentes

* **Umbriel:** Compositor Wayland leve (baseado em wlroots). Gerencia o posicionamento das janelas e os atalhos de teclado.
* **Noctalia:** Shell de desktop. Fornece papel de parede, barra superior, central de notificações e launcher via protocolo `wlr-layer-shell`.
* **Kitty:** Emulador de terminal padrão associado ao atalho `Mod + Enter` no Umbriel.
* **Greetd:** Gerenciador de login minimalista para Wayland que substitui o GDM padrão do GNOME.
* **Noctalia Greeter:** Interface visual moderna de login do Noctalia que roda em cima do Greetd.

---

# 🚀 1. Instalação Padrão (Máquina Física)

### Passo 1: Instalar o Noctalia e o Kitty

No terminal do Fedora, instale o Noctalia e o terminal Kitty:

```bash
sudo dnf install -y noctalia kitty
```

> **⚠️ Atenção:** Não tente testar o comando `noctalia` dentro do GNOME Terminal ou pelo TTY. O GNOME não suporta o protocolo `wlr-layer-shell` e o TTY não possui as variáveis da sessão gráfica ativas. O Noctalia só deve ser executado de dentro da sessão do Umbriel.

### Passo 2: Habilitar o repositório Terra

O compositor Umbriel e o Noctalia Greeter são disponibilizados pelo repositório Terra:

```bash
sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys
```

### Passo 3: Instalar o Umbriel, Greetd e Noctalia Greeter

```bash
sudo dnf install -y umbriel-nightly greetd noctalia-greeter
```

### Passo 4: Copiar o arquivo de configuração base

Ao instalar o Umbriel no Passo 3, o pacote cria automaticamente no sistema o arquivo `/usr/share/umbriel/config.toml`. Esse arquivo original já vem com centenas de linhas contendo atalhos de fábrica (como Mod+Return para o Kitty, regras de posicionamento e navegação) e outras opções avançadas comentadas.

Para que as nossas alterações tenham efeito e não sejam sobrescritas em atualizações do sistema, criamos a pasta do Umbriel dentro do seu usuário e copiamos esse arquivo original para `~/.config/umbriel/config.toml`:

```bash
mkdir -p ~/.config/umbriel
cp /usr/share/umbriel/config.toml ~/.config/umbriel/config.toml
```

### Passo 5: Configurar o autostart do Noctalia

Abra o arquivo copiado para edição:

```bash
nano ~/.config/umbriel/config.toml
```

Na seção `[general]`, adicione o Noctalia à lista de inicialização automática:

```toml
[general]
autostart = ["noctalia"]
```

*(Salve com `Ctrl + O`, `Enter` e saia com `Ctrl + X`).*

### Passo 6: Ajustar o nome da sessão para "Noctalia" (Opcional)

Para que a tela de login exiba a sessão com o nome **Noctalia** em vez de **Umbriel**:

```bash
sudo nano /usr/share/wayland-sessions/umbriel.desktop
```

Altere a linha `Name=` para `Noctalia`:

```ini
[Desktop Entry]
Name=Noctalia
Comment=Noctalia Desktop Shell
Exec=umbriel
Type=Application
```

*(Salve com `Ctrl + O`, `Enter` e saia com `Ctrl + X`).*

### Passo 7: Configurar o Noctalia Greeter no Greetd

Edite o arquivo de configuração do Greetd:

```bash
sudo nano /etc/greetd/config.toml
```

Deixe o arquivo configurado da seguinte forma:

```toml
[terminal]
vt = 1

[default_session]
command = "/usr/bin/noctalia-greeter-session"
user = "greetd"
```

> **⚠️ Detalhes Importantes:**
> 1. **Usuário no Fedora:** Mantenha obrigatoriamente `user = "greetd"`. A documentação genérica costuma citar `user = "greeter"`, mas no Fedora esse usuário não existe; o usuário oficial do sistema é `greetd`.
> 2. **Sem linhas duplicadas:** Certifique-se de que não há outra linha `command = "agreety..."` abaixo, caso contrário ela sobrescreverá a tela gráfica.

*(Salve com `Ctrl + O`, `Enter` e saia com `Ctrl + X`).*

### Passo 8: Substituir o GDM pelo Greetd e reiniciar

Desative o GDM antigo, ative o Greetd e reinicie:

```bash
sudo systemctl disable gdm
sudo systemctl enable greetd
sudo reboot
```

O sistema ligará direto na tela de login moderna do **Noctalia Greeter**. Basta selecionar seu usuário, digitar a senha e entrar no seu desktop.

---

# 🖥️ 2. Ajustes Específicos para Máquina Virtual (VMware / VBox)

Se você estiver instalando dentro de uma **Máquina Virtual**:

* Os **Passos de 1 a 4** e o **Passo 6** são feitos **exatamente da mesma forma**.
* No **Passo 5** e no **Passo 7**, você precisará aplicar ajustes para contornar as limitações do driver de vídeo virtual do VMware (`SVGA3D`).

---

### Ajuste A: Inicializar o Noctalia via Software (Passo 5)

No arquivo `~/.config/umbriel/config.toml`, na seção `[general]`:

```toml
[general]
autostart = ["env LIBGL_ALWAYS_SOFTWARE=1 noctalia"]
```

#### ⚠️ Por que esse ajuste é necessário na VM?

* **O Erro:** Sem essa variável, a tela fica preta e o Noctalia sofre um crash imediato acusando `Pipe quebrado / EPIPE` (`operation_errno=32`).
* **A Causa:** O driver virtual `SVGA3D` falha ao tentar compartilhar buffers de memória de GPU (DMA-BUF) sob o protocolo `wlr-layer-shell`. O Umbriel detecta a resposta corrompida e derruba o Noctalia.
* **A Solução:** O parâmetro `LIBGL_ALWAYS_SOFTWARE=1` força a renderização da interface via CPU (Mesa llvmpipe), ignorando os bugs do driver virtual.

---

### Ajuste B: Desativar o Cursor por Hardware no Umbriel (Passo 5)

Ainda no arquivo `~/.config/umbriel/config.toml`, na seção `[input.cursor]`:

```toml
[input.cursor]
hardware_cursor = false                          # Mude de true para false
```

#### ⚠️ Por que esse ajuste é necessário na VM?

* **O Erro:** A sessão carrega, os cliques funcionam, mas o ponteiro do mouse fica completamente invisível.
* **A Causa:** O VMware não emula adequadamente planos de cursor por hardware no Wayland.
* **A Solução:** Ao definir como `false`, o Umbriel renderiza o cursor diretamente no quadro da tela (via software).

---

### Ajuste C: Configurar o Noctalia Greeter para a VM (Passo 7)

No arquivo `/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "env LIBGL_ALWAYS_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 /usr/bin/noctalia-greeter-session"
user = "greetd"
```

#### ⚠️ Erros que acontecem na VM sem esses ajustes:

1. **Queda no terminal (`sh-5.3$`):**
   Se você deixar linhas repetidas no arquivo (como a linha original do `agreety`), o TOML sobrescreve o comando do Noctalia Greeter e executa a interface de texto de emergência.
2. **Falha por usuário inexistente:**
   Se utilizar `user = "greeter"`, o Greetd falha ao iniciar (`id: "greeter": usuário inexistente`). No Fedora, use sempre `user = "greetd"`.
3. **Tela preta ou cursor invisível no Login:**
   As variáveis `LIBGL_ALWAYS_SOFTWARE=1` e `WLR_NO_HARDWARE_CURSORS=1` garantem que o compositor interno do Greeter não sofra crash pelo driver do VMware e que a seta do mouse apareça para digitar a senha.

*(Depois de salvar o arquivo, prossiga com o **Passo 8** normalmente).*

---

## 📋 Resumo das Diferenças

| Configuração | Máquina Física (Seção 1) | Máquina Virtual (Seção 2) | Motivo da Diferença |
| :--- | :--- | :--- | :--- |
| **`config.toml` (Umbriel)**<br>`[general] -> autostart` | `["noctalia"]` | `["env LIBGL_ALWAYS_SOFTWARE=1 noctalia"]` | A GPU virtual quebra buffers compartilhados de Wayland (`Pipe quebrado`). |
| **`config.toml` (Umbriel)**<br>`[input.cursor] -> hardware_cursor` | `true` | `false` | Na VM, o plano de cursor por hardware fica invisível. |
| **`config.toml` (Greetd)**<br>`[default_session] -> command` | `"/usr/bin/noctalia-greeter-session"` | `"env LIBGL_ALWAYS_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1 /usr/bin/noctalia-greeter-session"` | Garante estabilidade de vídeo e visibilidade do cursor na tela de login da VM. |
| **`config.toml` (Greetd)**<br>`[default_session] -> user` | `"greetd"` | `"greetd"` | Em ambos os cenários no Fedora, o usuário padrão do sistema é `greetd` (não `greeter`). |
