# Port iOS — versão foreground-only

**Status:** especificação aprovada para implementação inicial. Espelhada de
[`junglivre/ProtopandaController`](https://github.com/junglivre/ProtopandaController), o app
Android original.

## 1. Decisão de produto

Criar um app iOS nativo em Swift que atua como periférico Bluetooth Low Energy (BLE) para um receptor Protopanda, mantendo o protocolo GATT e o formato do pacote do Android.

A primeira versão funciona somente enquanto o app está em primeiro plano e ativo. Ao perder o primeiro plano, bloquear a tela ou encerrar a sessão do controlador, ela interrompe a captura de sensores, as notificações e o advertising. Não declara `bluetooth-peripheral` em `UIBackgroundModes` e não implementa restauração de estado BLE nesta fase.

Essa decisão elimina o maior risco do port: o iOS reduz ou altera o comportamento de advertising em background e não oferece um equivalente ao foreground service Android. A Apple exige o modo `bluetooth-peripheral` para processar eventos de read, write e subscription em background; mesmo com esse modo, o sistema pode suspender ou encerrar o app. Fonte: [Core Bluetooth Background Processing for iOS Apps](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html).

## 2. Briefing

### Problema

A plataforma Protopanda precisa de um controle remoto por BLE. O controlador atual usa um telefone Android como periférico GATT, recebe um identificador do receptor e transmite sensores e botões em notificações periódicas.

### Público e contexto de uso

- Pessoa com um iPhone compatível com BLE e um receptor Protopanda.
- Uso interativo, com o controlador aberto e visível na tela.
- O receptor atua como central BLE e conhece o UUID do serviço.
- Não há conta, backend, login, telemetria ou pareamento manual dentro do app.

### Resultado esperado

Com o app aberto, o receptor encontra o iPhone pelo UUID de serviço, conecta, escreve o ID do controle e recebe, a cada 50 ms, os mesmos 23 bytes que recebe do Android. Toques e movimentos do iPhone alteram o pacote de forma compatível com o firmware existente.

## 3. Escopo

### Incluído na versão inicial

- App iOS nativo em Swift, com deployment target **iOS 15 ou superior**.
- Periférico GATT com UUIDs padrão configuráveis.
- Um central conectado por vez.
- Advertising conectável, sem nome local do dispositivo e contendo o UUID de serviço.
- Leitura e escrita da característica de ID.
- Característica de dados com leitura, subscribe e notify.
- Notificações com período nominal de 50 ms enquanto há central inscrito e ID válido.
- D-pad multitouch: direções, `OK`, `BACK`, `L1` e `R1`.
- Acelerômetro e giroscópio, com as mesmas escalas, filtro e limites do Android.
- Estado visual de advertising, conexão, espera por ID e erro de Bluetooth.
- Tela de configurações para os três UUIDs, restauração dos padrões e links de créditos/repositório.
- Persistência local dos UUIDs.
- Operação somente no primeiro plano.
- Política de privacidade específica para iOS antes da distribuição.

### Fora de escopo

- BLE em background, com tela bloqueada ou após o sistema suspender/encerrar o processo.
- Restauração de estado de `CBPeripheralManager`.
- Tentativa de manter sensores ou notificações após `scenePhase` deixar `.active`.
- Suporte a central BLE além do receptor Protopanda.
- Contas, rede, analytics, notificações push e backend.
- Download de avatares dos créditos. A tela iOS usa imagens incluídas no bundle ou apenas texto, sem acesso à rede.
- Portar a estrutura Android, Gradle, services, permissões Android ou o processo de encerrar o app.

## 4. Referência comportamental Android

| Componente Android | Comportamento que o iOS preserva |
| --- | --- |
| `BleIdentity` | Três UUIDs persistidos localmente; validação de UUID e exigência de valores distintos. |
| `BlePeripheralService.startGattServer()` | Serviço primário, característica read/write de ID, característica read/notify de dados e descritor CCCD. |
| `onCharacteristicWriteRequest()` | Write de exatamente 4 bytes em little-endian define o ID. |
| `buildPacket()` | Pacote de 23 bytes, ordem e encoding descritos abaixo. |
| `startNotifyLoop()` | Tentativa de notify a cada 50 ms, somente com central conectado, CCCD inscrito e ID definido. |
| `MainActivity.setupMultiTouchButtons()` | Toques simultâneos em vários botões atualizam todos os estados pressionados. |
| `MainActivity.onSensorChanged()` | Filtro, conversão e saturação dos sensores. |
| `SettingsActivity.save()` | Salvar UUIDs desconecta o receptor e recria o periférico com a nova identidade. |

## 5. Contrato BLE obrigatório

### UUIDs padrão

| Item | UUID |
| --- | --- |
| Serviço primário | `d4d31337-c4c1-c2c3-b4b3-b2b1a4a3a2a1` |
| Característica read/write | `d4d3fafb-c4c1-c2c3-b4b3-b2b1a4a3a2a1` |
| Característica read/notify | `d4d3afaf-c4c1-c2c3-b4b3-b2b1a4a3a2a1` |
| CCCD | `00002902-0000-1000-8000-00805f9b34fb` |

O app anuncia apenas o UUID de serviço. Não inclui nome local do dispositivo no advertising.

### GATT

| Característica | Propriedades | Semântica |
| --- | --- | --- |
| read/write | `.read`, `.write` | O central escreve 4 bytes little-endian com o ID. Uma leitura devolve o mesmo `Int32` little-endian. |
| notify | `.read`, `.notify` | Uma leitura devolve o pacote atual. Após subscription no CCCD, o app tenta enviar o pacote periodicamente. |

O app aceita somente um central. Quando um central conecta, ele para o advertising. Ao desconectar, ele limpa subscription e ID e reinicia o advertising enquanto continuar em primeiro plano.

Uma escrita com tamanho diferente de 4 bytes recebe sucesso GATT, como no Android, mas não altera o ID. O byte do pacote preserva os 8 bits menos significativos do `Int32`, como faz o Android ao converter o ID para `Byte`.

### Pacote de dados

Cada pacote tem exatamente 23 bytes e usa ordem little-endian.

| Offset | Tamanho | Campo | Tipo / regra |
| ---: | ---: | --- | --- |
| 0 | 2 | `accZ` | `Int16` little-endian |
| 2 | 2 | `accX` | `Int16` little-endian |
| 4 | 2 | `accY` | `Int16` little-endian |
| 6 | 2 | `gyroZ` | `Int16` little-endian |
| 8 | 2 | `gyroX` | `Int16` little-endian |
| 10 | 2 | `gyroY` | `Int16` little-endian |
| 12 | 2 | temperatura | sempre `0` |
| 14 | 1 | ID | byte menos significativo do ID recebido |
| 15 | 1 | botão `right` | `0` ou `1` |
| 16 | 1 | botão `down` | `0` ou `1` |
| 17 | 1 | botão `left` | `0` ou `1` |
| 18 | 1 | botão `up` | `0` ou `1` |
| 19 | 1 | botão `ok` | `0` ou `1` |
| 20 | 1 | botão `back` | `0` ou `1` |
| 21 | 1 | botão `l1` | `0` ou `1` |
| 22 | 1 | botão `r1` | `0` ou `1` |

O pacote não pode alterar ordem, tamanho, endianess, sinal ou o placeholder de temperatura sem uma mudança compatível no firmware do receptor.

## 6. Sensores e controles

### Sensores

Usar `CMMotionManager` para ler acelerômetro e giroscópio enquanto a cena está ativa. O iPhone deve possuir ambos; caso um esteja indisponível, o app mantém os respectivos eixos em zero e exibe o estado degradado, sem impedir os controles touch.

Aplicar exatamente as regras do Android:

```text
alpha = 0.8
accFiltrado = alpha * accFiltrado + (1 - alpha) * accBruto
accInt16 = clamp(Int(accFiltrado / 9.81 * (32768 / 4)), -32768, 32767)
gyroGrausPorSegundo = radianosPorSegundo * 180 / pi
gyroInt16 = clamp(Int(gyroGrausPorSegundo * (32768 / 2000)), -32768, 32767)
```

A UI mostra os valores filtrados de aceleração em m/s² e de giro em °/s. O envio BLE usa os `Int16` convertidos.

### Botões

O container dos controles precisa rastrear todos os dedos ativos, não apenas o último evento. Botões pressionados simultaneamente mantêm estado `1`; o botão muda para `0` somente quando nenhum dedo ainda estiver sobre sua área.

Mapeamento obrigatório:

```text
right=0, down=1, left=2, up=3, ok=4, back=5, l1=6, r1=7
```

## 7. Requisitos de interface e ciclo de vida

### Tela principal

- Orientação retrato.
- Barra superior: indicador de estado, botão de configurações e botão para encerrar a sessão do controlador.
- Exibir versão e leituras IMU.
- D-pad e botões com áreas de toque dimensionadas para uso com vários dedos.
- Estados: `Bluetooth indisponível`, `Anunciando`, `Conectado — aguardando ID`, `Conectado — ID N`, `Erro de BLE` e `Sensores indisponíveis`.

O iOS não permite que o app encerre seu próprio processo. O botão equivalente a `Exit` deve se chamar **Encerrar controlador**: parar advertising, remover os serviços publicados, zerar estado da sessão e voltar a um estado ocioso. Ele não chama APIs privadas nem tenta fechar o app.

### Configurações

- Campos para UUID de serviço, read/write e notify.
- Rejeitar texto que não seja UUID válido.
- Rejeitar UUIDs duplicados.
- Salvar em `UserDefaults`.
- Ao salvar, parar advertising, limpar o estado local da sessão e reconstruir os serviços GATT com a nova identidade. `CBPeripheralManager` não expõe uma API para desconectar o central; o receptor precisa encerrar e refazer a conexão para usar a identidade nova.
- Restaurar os três valores padrão.
- Mostrar versão, repositório e créditos.

### Primeiro plano

- A sessão inicia somente depois de `CBPeripheralManager` informar estado `.poweredOn` e a tela estar ativa.
- Em `.inactive` ou `.background`, parar atualizações do `CMMotionManager`, parar o timer de notify e parar advertising. Desconexões durante a suspensão não são tratadas como continuidade de sessão.
- Ao voltar a `.active`, recriar/publicar o GATT se necessário e iniciar advertising se não houver central conectado.
- Se Bluetooth ficar indisponível, limpar conexão, subscription e ID; mostrar o erro. Se voltar a `.poweredOn` com a tela ativa, publicar e anunciar de novo.

## 8. Arquitetura proposta

```text
SwiftUI App / Scene lifecycle
        │
        ├── ControllerViewModel (@MainActor)
        │      ├── estado visual, botões e UUIDs
        │      └── coordena sessão no primeiro plano
        │
        ├── BLEPeripheralController (CoreBluetooth, fila serial própria)
        │      ├── CBPeripheralManagerDelegate
        │      ├── publicação GATT, advertising e central inscrito
        │      ├── read/write requests e subscription
        │      └── notify / backpressure de updateValue
        │
        ├── MotionController (CoreMotion)
        │      └── filtro e conversão de sensores
        │
        ├── ControllerInputState
        │      └── sensores, ID e oito estados de botão
        │
        ├── PacketEncoder
        │      └── transforma ControllerInputState em 23 bytes
        │
        └── BLEIdentityStore (UserDefaults)
```

Regras de fronteira:

- `PacketEncoder` é puro e recebe valores explícitos. Testes unitários validam seus bytes sem CoreBluetooth, UI ou sensores.
- `BLEPeripheralController` é o único dono de `CBPeripheralManager`, dos serviços GATT e da lista de centrals inscritos.
- Uma fila serial protege callbacks CoreBluetooth. O estado que sensores/UI compartilham com o encoder deve ser sincronizado de forma explícita; não acessar objetos SwiftUI diretamente nessa fila.
- `updateValue(_:for:onSubscribedCentrals:)` pode recusar dados por backpressure. Nesse caso, descartar o frame antigo e reenviar somente o estado mais recente quando `peripheralManagerIsReady(toUpdateSubscribers:)` ocorrer. Não formar fila de pacotes obsoletos.
- O timer de 50 ms existe somente com central inscrito, ID válido e cena ativa. Não registrar logs por frame.

> **Nota de implementação:** a versão inicial implementada em `App/Sources/BLEPeripheralController.swift`
> roda inteiramente na main actor/queue (o `CBPeripheralManager` é criado com `queue: nil`), em
> vez de uma fila serial dedicada — Core Bluetooth exige que toda chamada ao gerenciador ocorra
> na mesma fila usada na inicialização, e manter tudo na main actor evita qualquer salto entre
> filas/atores. `ControllerInputState` continua sendo o ponto único e thread-safe (via `NSLock`)
> onde sensores, botões e BLE se encontram.

## 9. Requisitos de plataforma, privacidade e distribuição

- A compilação requer Xcode em macOS, mas não exige um Mac próprio: uma runner macOS hospedada, como GitHub Actions, pode executar o build. A Apple mantém Xcode e os SDKs iOS vinculados a versões de macOS: [requisitos do Xcode](https://developer.apple.com/xcode/system-requirements/).
- Testar em iPhone físico que suporte BLE peripheral; simulador não valida advertising, GATT peripheral nem sensores reais.
- Declarar `NSBluetoothAlwaysUsageDescription`, com texto que explique a conexão direta com o receptor Protopanda.
- Declarar `NSMotionUsageDescription`, com texto que explique os controles de movimento, se a versão/iOS exigir a chave para Core Motion.
- Não incluir `UIBackgroundModes` nesta versão.
- Não solicitar contatos, fotos, microfone, localização, notificações, rede celular ou tracking.
- Não incluir SDKs de analytics, publicidade, crash reporting remoto ou backend.
- Guardar somente os três UUIDs em `UserDefaults`.
- Enviar somente dados de sensores, botão e ID ao receptor BLE diretamente conectado; não enviar dados a servidores.
- Atualizar ou criar a política de privacidade de modo que ela cite iOS e remova qualquer declaração incompatível com a implementação publicada.

### Desenvolvimento sem Mac próprio

O fluxo viável para este projeto é editar no Linux, compilar em uma runner macOS com Xcode e instalar o IPA no iPhone pelo SideStore. Não existe build iOS nativo completo no Linux porque o SDK e o `xcodebuild` pertencem ao Xcode/macOS.

1. O repositório aciona uma workflow GitHub Actions em imagem `macos-*`.
2. A workflow compila o target para `iphoneos`/`arm64`, executa os testes unitários do protocolo e publica um IPA como artifact.
3. O IPA é baixado no iPhone e instalado **diretamente pelo SideStore**. O SideStore assina ou reassina apps com o certificado pessoal do Apple ID e mantém o ciclo de desenvolvimento de sete dias por refresh: [FAQ do SideStore](https://docs.sidestore.io/docs/faq).
4. O teste BLE é feito no iPhone físico com o receptor Protopanda. O simulador não substitui essa etapa.

Com Apple ID gratuito, o SideStore informa limite de três apps ativos, incluindo o próprio SideStore, e dez App IDs por semana. O controlador deve ocupar um slot próprio durante os testes e requer refresh antes do certificado de desenvolvimento expirar. Uma conta Apple Developer paga amplia o ciclo para 365 dias e remove a restrição de três apps citada pelo SideStore.

Sem Xcode local, os limites práticos são depuração e iteração: não há debugger visual, console de dispositivo ou Instruments local. A workflow deve preservar logs de build e testes; a tela do app deve exibir estado BLE, ID, advertising e dados IMU suficientes para diagnosticar o teste físico.

TestFlight e App Store continuam possíveis sem Mac próprio, mas exigem uma conta Apple Developer paga, credenciais de assinatura protegidas nos secrets da CI e upload pela runner macOS. Não usar credenciais Apple pessoais como secrets de repositório.

## 10. Plano de desenvolvimento

### Fase 1 — Bootstrap iOS

1. Criar target iOS Swift/SwiftUI e configurar bundle identifier, assets e versão.
2. Configurar as duas descrições de uso exigidas em `Info.plist`.
3. Criar a tela principal estática e a tela de configurações.
4. Confirmar em iPhone físico que `CBPeripheralManager` chega a `.poweredOn`.

**Saída:** app abre em retrato, exibe estado Bluetooth e não pede permissões fora do escopo.

### Fase 2 — Núcleo de protocolo

1. Implementar `BLEIdentityStore`, `ControllerInputState` e `PacketEncoder`.
2. Escrever testes de vetor para o pacote de 23 bytes, valores negativos, saturação e mapeamento de botões.
3. Implementar publicação do serviço e das duas características.
4. Implementar read, write de ID e subscription; writes fora de 4 bytes devem manter o ID, mas responder sucesso para preservar o comportamento Android.

**Saída:** um central BLE de diagnóstico lê o ID, escreve um ID e recebe os bytes esperados.

### Fase 3 — Sessão BLE foreground

1. Implementar advertising sem nome local e com UUID de serviço.
2. Limitar a um central, controlar subscription e reiniciar advertising após desconexão.
3. Implementar o timer nominal de 50 ms e backpressure do CoreBluetooth.
4. Aplicar as transições de `scenePhase` para parar e reiniciar a sessão.

**Saída:** receptor Protopanda conecta e recebe atualizações contínuas enquanto o app está ativo.

### Fase 4 — Entradas e interface

1. Implementar leitura de acelerômetro e giroscópio com o filtro e escalas definidos.
2. Implementar D-pad multitouch e os oito estados de botão.
3. Atualizar status e valores IMU na tela sem fazer trabalho BLE na main thread.
4. Implementar configurações, validação e reconstrução segura da identidade GATT.

**Saída:** toque e movimento alteram os controles do receptor com a mesma orientação e escala do Android.

### Fase 5 — Validação e publicação

1. Executar a matriz de testes abaixo em iPhones físicos e com o receptor real.
2. Corrigir divergências medidas de bytes, eixos, cadência e reconexão.
3. Revisar a política de privacidade, metadados da App Store, ícones e screenshots.
4. Distribuir primeiro por TestFlight; publicar somente após validação do receptor.

## 11. Matriz de verificação e critérios de aceite

| ID | Cenário | Evidência de aceite |
| --- | --- | --- |
| P01 | Valores padrão | Serviço e características usam os três UUIDs definidos na seção 5. |
| P02 | Advertising | O receptor Protopanda descobre e conecta ao iPhone pelo UUID de serviço, sem depender de nome local. |
| P03 | ID | Write de 4 bytes little-endian atualiza a UI e leitura retorna o mesmo `Int32` little-endian. |
| P04 | Write fora do tamanho | Write com tamanho diferente de 4 bytes recebe sucesso GATT e não altera o ID atual. |
| P05 | Pacote | Captura BLE confirma 23 bytes, offsets, valores little-endian e temperatura zero. |
| P06 | Cadência | Com subscriber e ID, o receptor observa atualizações próximas de 50 ms enquanto o app permanece ativo. |
| P07 | Botões | Cada botão altera seu offset; dois ou mais dedos mantêm todos os botões correspondentes pressionados. |
| P08 | Movimento | Inclinar e girar o iPhone produz eixos, sinal e escala aceitos pelo receptor; valores extremos saturam em `Int16`. |
| P09 | Desconexão | Desconectar o receptor limpa ID/subscription e torna o iPhone descobrível novamente enquanto a tela está ativa. |
| P10 | UUIDs customizados | Salvar UUIDs válidos distintos reconstrói os serviços locais; após o receptor reconectar, ele usa a nova identidade. |
| P11 | Ciclo foreground | Sair do primeiro plano interrompe envio; retornar com Bluetooth ativo recria a sessão e volta a anunciar. |
| P12 | Hardware degradado | Falta de acelerômetro ou giroscópio mantém o app utilizável pelo touch e transmite zero nos eixos indisponíveis. |
| P13 | Privacidade | Inspeção do binário confirma ausência de SDKs de analytics/ads e de tráfego de rede da aplicação. |

## 12. Riscos e decisões de teste

| Risco | Mitigação |
| --- | --- |
| O receptor não encontra advertising do iPhone | Validar P02 primeiro, com o receptor real. A descoberta por UUID é o contrato crítico. |
| Eixos iOS diferem da orientação Android | Comparar P08 com o mesmo movimento físico e ajustar somente após medir a divergência. |
| `updateValue` aplica backpressure | Manter apenas o frame atual; nunca enfileirar estado antigo. |
| Tela bloqueada ou app em background interrompem o controle | Comportamento esperado e declarado para esta versão. A UI deve informar que a sessão requer primeiro plano. |
| Encerrar processo não é permitido no iOS | Encerrar somente a sessão BLE, sem APIs privadas. |
| Simulador produz falso positivo | Todo aceite BLE e IMU depende de iPhone físico e receptor Protopanda real. |

## 13. Próxima decisão após a versão inicial

Só considerar background após os testes foreground passarem no receptor. Esse trabalho forma uma segunda especificação: `bluetooth-peripheral`, state restoration, política explícita para lock screen, consumo de bateria e testes de advertising em background. Ele não entra como alteração incremental silenciosa nesta versão.
