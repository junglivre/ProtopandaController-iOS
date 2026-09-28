# Protopanda Controller

<p align="center">
  <img src="https://github.com/mockthebear/proto-panda/raw/main/doc/logoprotopanda.png" alt="Logo do Protopanda">
</p>

[🇺🇸 English](README.md) | **🇧🇷 Português**

Porte nativo para iOS do [Protopanda Controller](https://github.com/junglivre/ProtopandaController) (Android). Atua como periférico Bluetooth Low Energy (BLE) para plataformas Protopanda, enviando os dados de movimento do iPhone e o estado dos botões na tela pelo mesmo protocolo do app Android.

## Releases

[Baixe a última release](https://github.com/junglivre/ProtopandaController-iOS/releases/latest): um `.ipa` sem assinatura, pronto pra sideload com SideStore, AltStore ou iLoader.

## Estrutura do repositório

| Caminho | Função |
|---|---|
| `ProtopandaControllerCore/` | Swift Package puro: modelo de identidade BLE, encoder de pacote, matemática de escala de movimento, hit-testing multitoque. Multiplataforma, testado por CI no Linux. |
| `App/` | Target do app iOS: UI em SwiftUI, controlador de periférico Core Bluetooth, leitura de sensores Core Motion. Gerado com [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `App/project.yml`, compilado com Xcode no macOS. |

## Requisitos

- iOS 15 ou superior.
- Um iPhone cujo chipset Bluetooth suporte periférico BLE e modo de anúncio.
- Acelerômetro e giroscópio para os controles de movimento.
- Não precisa de Mac para desenvolver: veja [Compilar sem Mac](#compilar-sem-mac).

## Compilar sem Mac

Este ambiente de desenvolvimento não tem Xcode local, então o projeto é compilado de duas formas:

1. **Lógica pura** (`ProtopandaControllerCore/`): Swift puro, testado com `swift test` no Linux (funciona localmente também, por exemplo via a imagem Docker oficial `swift`, já que não depende de nenhum framework da Apple).
2. **App iOS** (`App/`): compilado por uma runner `macos-latest` do GitHub Actions (veja [`.github/workflows/ci.yml`](.github/workflows/ci.yml)). A workflow instala o [XcodeGen](https://github.com/yonaskolb/XcodeGen), gera o `.xcodeproj` a partir de `App/project.yml`, e roda `xcodebuild` com assinatura desabilitada para gerar um `.app` sem assinatura, empacotado como o artifact `ProtopandaController-unsigned-ipa`.

Dar push numa tag de versão semântica (ex.: `git tag 1.1.0 && git push origin 1.1.0`) roda o [`.github/workflows/release.yml`](.github/workflows/release.yml), que cria um [Release do GitHub](../../releases) com notas tiradas do `CHANGELOG.md` e anexa o `.ipa` cru direto como asset do release (sem zip extra). No iPhone, abra o release no Safari e baixe o `.ipa` direto pro SideStore, AltStore ou iLoader — isso funciona a partir do próprio iOS, ao contrário dos artifacts do GitHub Actions, que sempre vêm embrulhados em zip e são difíceis de extrair no Safari mobile. O SideStore reassina o app inteiro com o certificado pessoal do Apple ID, então o IPA não precisa vir assinado.

O simulador não faz parte deste pipeline: periférico Core Bluetooth, advertising e sensores de movimento reais só funcionam em dispositivo físico, então o teste de aceite sempre acontece por sideload num iPhone, contra um receptor Protopanda real.

## Sobre e créditos

- [GooDDu](https://github.com/GooDDu) — primeira versão do app Android.
- [mockthebear](https://github.com/mockthebear) — criador do Protopanda.
- [junglivre](https://github.com/junglivre) — porte iOS e melhorias do app Android.
