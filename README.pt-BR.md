[English](README.md) | **Português (Brasil)**

# Temas de Troféus PS5 para Steam Achievement Notifier

Temas de notificação de troféus no estilo PS5 para o [Steam Achievement Notifier](https://github.com/steamachievementnotifier/steamachievementnotifier) (SAN), para Windows e Linux.

## O que está incluído

| Arquivo | Slot do Modo Troféu do SAN |
| --- | --- |
| `themes/1.ps5_bronze.san` | Bronze → Bronze (principal) |
| `themes/2.ps5_silver.san` | Silver → Silver (semi) |
| `themes/3.ps5_gold.san` | Gold → Gold (rare) |
| `themes/4.ps5_platinum.san` | Platinum → Platinum (plat) |

O tema de platina usa o troféu animado em `.webp` e o som de platina. Os outros três usam o som padrão de troféu.

## Requisitos

- Steam Achievement Notifier instalado e aberto pelo menos uma vez (Windows ou Linux AppImage).
- Somente para o instalador no Linux: `python3`.

## Instalação automática

**Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/ianraubet/san-ps5-trophy-themes/main/install/install.sh | bash
```

Ou a partir de um clone deste repositório:

```bash
./install/install.sh
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/ianraubet/san-ps5-trophy-themes/main/install/install.ps1 | iex
```

Ou a partir de um clone deste repositório:

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1
```

### O que o instalador faz

1. Pede para você fechar o SAN antes (ele não pode estar em execução).
2. Faz backup do `config.json` do SAN como `config.json.bak-<timestamp>` na pasta de dados do SAN.
3. Extrai cada tema para a pasta `userthemes` do SAN.
4. Adiciona os quatro temas (substituindo se já existirem) e os ativa.
5. Ativa o Modo Troféu.

Opções:

- `--dir <caminho>` (Linux) / `-SanDir <caminho>` (Windows): aponta o instalador para a pasta de dados do SAN, caso ela não esteja no local padrão.
- `--no-activate` (Linux) / `-NoActivate` (Windows): apenas adiciona os temas, sem trocar o tema ativo nem ligar o Modo Troféu.

Locais da pasta de dados do SAN:

- Linux: `~/.local/share/Steam Achievement Notifier (V<versão>)`
- Windows: `%LOCALAPPDATA%\Steam Achievement Notifier (V<versão>)`

### Restaurando suas configurações anteriores

Feche o SAN e copie o backup por cima do `config.json` na pasta de dados do SAN.

## Instalação manual

1. No SAN, ative **Settings → Trophy Mode** (Configurações → Modo Troféu).
2. Para cada tipo de notificação, abra **Customiser → Theme Switcher → Import** (Personalizador → Trocador de Tema → Importar) e escolha o arquivo `.san` correspondente em `themes/`.

## Recursos brutos

Para quem quiser criar os próprios temas:

- `images/`: ícones de troféus (bronze, silver, gold, plat, hidden) e o ícone do botão PS.
- `sounds/`: sons de troféu e de platina (`.mp3`).
- `videos/`: o troféu de platina animado (`.webp`).

## Licença

- A licença MIT (veja [LICENSE](LICENSE)) cobre as configurações de tema, os scripts de instalação e a documentação.
- Os ícones, sons e a animação de troféus são propriedade da Sony Interactive Entertainment e são incluídos apenas para personalização não comercial. As imagens do projeto SAN incluídas nos arquivos `.san` pertencem ao Steam Achievement Notifier. Veja [NOTICE.md](NOTICE.md) para detalhes.
- Este projeto não é afiliado nem endossado pela Sony, pela Valve ou pelo projeto Steam Achievement Notifier. "PlayStation" e "PS5" são marcas da Sony.
