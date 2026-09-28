# Protopanda Controller — iOS

[🇺🇸 English](README.md) | [🇧🇷 Português](README.pt-BR.md)

Porte nativo para iOS, restrito a primeiro plano, do [Protopanda Controller](https://github.com/junglivre/ProtopandaController) (Android). Atua como periférico Bluetooth Low Energy (BLE) para plataformas Protopanda, enviando os dados de movimento do iPhone e o estado dos botões na tela pelo mesmo protocolo do app Android.

Este app funciona somente enquanto está aberto e em primeiro plano. Ele não solicita o modo de background `bluetooth-peripheral`; sair do app ou bloquear a tela interrompe advertising, sensores e notificações. Veja [`docs/ios-foreground-port.md`](docs/ios-foreground-port.md) para a especificação completa, briefing, contrato de protocolo, arquitetura e matriz de testes.

## Estrutura do repositório

| Caminho | Função |
|---|---|
| `ProtopandaControllerCore/` | Swift Package puro: modelo de identidade BLE, encoder de pacote, matemática de escala de movimento, hit-testing multitoque. Multiplataforma, testado por CI no Linux. |
| `App/` | Target do app iOS: UI em SwiftUI, controlador de periférico Core Bluetooth, leitura de sensores Core Motion. Gerado com [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `App/project.yml`, compilado com Xcode no macOS. |
| `docs/` | Especificação e briefing deste porte. |

## Requisitos

- iOS 15 ou superior.
- Um iPhone cujo chipset Bluetooth suporte periférico BLE e modo de anúncio.
- Acelerômetro e giroscópio para os controles de movimento.
- Não precisa de Mac para desenvolver: veja [Compilar sem Mac](#compilar-sem-mac).

## Compilar sem Mac

Este ambiente de desenvolvimento não tem Xcode local, então o projeto é compilado de duas formas:

1. **Lógica pura** (`ProtopandaControllerCore/`): Swift puro, testado com `swift test` no Linux (funciona localmente também, por exemplo via a imagem Docker oficial `swift`, já que não depende de nenhum framework da Apple).
2. **App iOS** (`App/`): compilado por uma runner `macos-latest` do GitHub Actions (veja [`.github/workflows/ci.yml`](.github/workflows/ci.yml)). A workflow instala o [XcodeGen](https://github.com/yonaskolb/XcodeGen), gera o `.xcodeproj` a partir de `App/project.yml`, e roda `xcodebuild` com assinatura desabilitada para gerar um `.app` sem assinatura, empacotado como o artifact `ProtopandaController-unsigned-ipa`.

Todo push na `main` publica um [Release do GitHub](../../releases) com tag igual ao SHA curto do commit (ex.: `485b3f8`), com o `ProtopandaController-unsigned.ipa` cru anexado direto como asset do release (sem zip extra). No iPhone, abra o release no Safari e baixe o `.ipa` direto pro SideStore, AltStore ou iLoader — isso funciona a partir do próprio iOS, ao contrário dos artifacts do GitHub Actions, que sempre vêm embrulhados em zip e são difíceis de extrair no Safari mobile. O SideStore reassina o app inteiro com o certificado pessoal do Apple ID, então o IPA não precisa vir assinado.

O simulador não faz parte deste pipeline: periférico Core Bluetooth, advertising e sensores de movimento reais só funcionam em dispositivo físico, então o teste de aceite sempre acontece por sideload num iPhone, contra um receptor Protopanda real.

## Lacunas conhecidas nesta primeira versão

- Sem testes de UI automatizados; `docs/ios-foreground-port.md` §11 lista a matriz de aceite manual (P01–P13) para rodar contra um receptor Protopanda real.
- BLE em background, operação com tela bloqueada e restauração de estado do Core Bluetooth ficam fora do escopo desta versão (§13 da especificação).

## Sobre e créditos

- [GooDDu](https://github.com/GooDDu) — primeira versão do app Android.
- [mockthebear](https://github.com/mockthebear) — criador do Protopanda.
- [junglivre](https://github.com/junglivre) — porte iOS e melhorias do app Android.
