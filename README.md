# Tamagotchi · Quintal

Primeira versão jogável em **Godot 4.7.2 / GDScript / 2D**. Abra `project.godot` e pressione **F6** na cena `tamagotchi.tscn`, ou **F5** para executar o projeto.

## Como jogar

- **Dar alimento** oferece uma porção da despensa diretamente ao bichinho, com reação visual. Não mexe na comida do pote. Ele aceita comida enquanto tiver fome e estiver acordado; de barriga cheia, não gasta porções.
- **Potes e cuidados → Encher o potinho** deixa comida para ele comer sozinho depois. O consumo autônomo usa apenas os potes, nunca os estoques. Nesse menu também ficam água, banheiro e sono.
- A tela principal mostra o bichinho, saciedade, água e energia. Estoques, saúde, rotina e diário ficam em **Ver detalhes**.
- Despensa: **10 comidas**; pote: **3 porções**. Reservatório: **2000 ml**; pote: **300 ml**.
- Explore o jardim com **WASD, setas ou clique**. Colete frutas e gotas em 30 segundos; cada gota vale 150 ml. Pode voltar antes com o que coletou. O excedente é informado e fica no jardim.
- Cada partida custa **18 de energia** ao começar e acrescenta **45 minutos** ao descanso. Sair cedo não devolve energia. Não é possível jogar dormindo ou sem energia suficiente.
- Leve ao banheiro após aproximadamente **12 horas**. Com **14 horas**, fica urgente; com **16**, ocorre um acidente. Limpe o ambiente para interromper a penalidade de higiene.
- O sono começa automaticamente às **22h**, ou pelo botão Dormir. Uma sessão normal exige **8 horas**, mais o descanso das atividades. Acordar antes mantém o progresso e retoma o sono após uma hora. A energia não cai passivamente.
- O relógio real aparece na tela. Pode fechar o jogo: os cuidados continuam sendo calculados na próxima abertura.

## Regras de tempo e equilíbrio

Todos os indicadores visíveis são melhores quando altos. **Saciedade = 100 − fome**: os antigos 12% de fome agora aparecem como 88% de saciedade. A fome interna cresce 4,5 pontos/hora. Há até uma refeição automática por período, quando a fome chega a 25: manhã 06–11:59, tarde 12–17:59, noite 18–23:59. Uma porção reduz 36 pontos. Alimentar na mão permite antecipar uma refeição e conta como a refeição do período.

A hidratação diminui progressivamente. Acordado, o bichinho bebe aproximadamente 100 ml a cada 4 horas; durante o sono, o consumo metabólico cai pela metade e ele bebe ao acordar. Quantidades parciais também ajudam. Potes vazios nunca geram recursos.

Fome extrema, desidratação e sujeira prejudicam a saúde. Cuidados adequados recuperam a saúde gradualmente. **Esta etapa não tem morte permanente**: a saúde tem piso de 10%, permitindo recuperar o bichinho após ausências longas.

A simulação integra intervalos entre eventos de necessidade, mudanças de hora, acidentes e fim de sono. Não reproduz frames nem segundos offline. Ausências acima de **7 dias** têm o trecho excedente congelado e processam no máximo os últimos 7 dias, com aviso. Se o relógio retroceder, o estado espera o último instante salvo sem aplicar tempo negativo. O fuso salvo é usado no intervalo offline; o fuso atual do sistema é adotado ao abrir.

## Salvamento

`user://pet_v1.json`, no Windows normalmente `%APPDATA%/Godot/app_userdata/Tamagotchi/`. Salva nas ações, a cada 30 segundos, ao perder foco e ao fechar. Usa arquivo temporário e cópia `.bak`; dados inválidos são validados e há recuperação da cópia. Um save inválido sem cópia válida é preservado como `.invalid` antes de iniciar uma nova rotina.

## Laboratório e testes

**F3** abre o laboratório em builds de desenvolvimento. Avance 4, 8, 12 ou 24 horas, volte à tela do bichinho para testar cuidados e reabra F3 para encerrar. O laboratório usa uma cópia temporária: não salva os avanços nem as recompensas na partida real. Encerrar restaura a partida; fechar o jogo também a restaura.

Com o executável Godot no PATH:

```powershell
godot --headless --path . --script tests/test_care.gd
godot --headless --path . --script tests/test_ui.gd
godot --headless --path . --script tests/test_restart.gd -- --write-fixture
godot --headless --path . --script tests/test_restart.gd
```

Os dois últimos comandos testam persistência entre processos e seis horas offline, em arquivo separado do save do jogador. Para capturas com renderização real:

```powershell
godot --path . --script tests/test_ui.gd -- --capture-test
```

As imagens ficam em `tests/artifacts/`. Os testes de interface exercitam os controles, o evento de clique, movimento, coleta, término, recompensa, sono e isolamento do laboratório. Não substituem uma avaliação humana do equilíbrio de longo prazo.

## Organização

| Arquivo | Responsabilidade |
| --- | --- |
| `rules.gd` | Capacidades, taxas, períodos e relógio local |
| `pet_state.gd` | Estado serializável e validação |
| `care.gd` | Simulação temporal, necessidades, sono e decisões |
| `inventory.gd` | Transferências e recompensas limitadas |
| `save_store.gd` | Persistência e recuperação |
| `main.gd` | Interface, comandos e ciclo da aplicação |
| `pet_view.gd` | Desenho e animação do bichinho/potes |
| `collection_game.gd` | Minijogo interativo |

A auditoria identificou uma cena, três scripts e duas cópias temporárias da cena original. Os scripts antigos duplicavam decisões, acoplavam regras à interface, geravam comida infinita e usavam segundos de execução para necessidades. Foram substituídos; a arte agora é procedural, simples e independente das regras.
