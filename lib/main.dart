import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ihyocobxfhvxelrwokds.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImloeW9jb2J4Zmh2eGVscndva2RzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2OTMxMDgsImV4cCI6MjEwNzI2OTEwOH0._KyKVzIlnh_TDICrlAzPBsbhuzg3i6nzM-GnHvAYzMk',
  );

  runApp(const AppControleFrota());
}

// Função auxiliar para atualizar a KM do Veículo se o novo valor for maior
Future<void> _atualizarKmVeiculoSeMaior(dynamic veiculoId, String novaKmStr) async {
  try {
    final double novaKm = double.tryParse(novaKmStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    if (novaKm <= 0) return;

    final veiculo = await supabase.from('veiculos').select('quilometragem').eq('id', veiculoId).single();
    final double kmAtual = double.tryParse(veiculo['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;

    if (novaKm > kmAtual) {
      await supabase.from('veiculos').update({
        'quilometragem': '${novaKm.toStringAsFixed(0)} km',
      }).eq('id', veiculoId);
    }
  } catch (e) {
    debugPrint('Erro ao atualizar KM do veículo: $e');
  }
}

class AppControleFrota extends StatelessWidget {
  const AppControleFrota({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Frota',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  List<Map<String, dynamic>> veiculos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarVeiculos();
  }

  Future<void> _carregarVeiculos() async {
    try {
      final resposta = await supabase
          .from('veiculos')
          .select()
          .order('id', ascending: false);

      setState(() {
        veiculos = List<Map<String, dynamic>>.from(resposta);
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar veículos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Frota (Supabase)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // BOTÃO DO DASHBOARD ADICIONADO AQUI
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Dashboard Financeiro',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TelaDashboard(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _carregando = true);
              _carregarVeiculos();
            },
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : veiculos.isEmpty
              ? const Center(child: Text('Nenhum veículo cadastrado na nuvem.'))
              : ListView.builder(
                  itemCount: veiculos.length,
                  itemBuilder: (context, index) {
                    final veiculo = veiculos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.directions_car),
                        ),
                        title: Text(
                          '${veiculo['modelo'] ?? 'Sem modelo'} - ${veiculo['placa'] ?? 'Sem placa'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Quilometragem Atual: ${veiculo['quilometragem'] ?? 'Não informada'}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaDetalhesVeiculo(veiculo: veiculo),
                            ),
                          );
                          _carregarVeiculos();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final atualizado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const TelaCadastroVeiculo()),
          );

          if (atualizado == true) {
            setState(() => _carregando = true);
            _carregarVeiculos();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Veículo'),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE DETALHES DO VEÍCULO
// ----------------------------------------------------
class TelaDetalhesVeiculo extends StatefulWidget {
  final Map<String, dynamic> veiculo;

  const TelaDetalhesVeiculo({super.key, required this.veiculo});

  @override
  State<TelaDetalhesVeiculo> createState() => _TelaDetalhesVeiculoState();
}

class _TelaDetalhesVeiculoState extends State<TelaDetalhesVeiculo> {
  List<Map<String, dynamic>> manutencoes = [];
  bool _carregando = true;
  bool _alertaRevisaoPendente = false;

  @override
  void initState() {
    super.initState();
    _carregarManutencoes();
  }

  Future<void> _carregarManutencoes() async {
    try {
      final veiculoId = widget.veiculo['id'];
      final resposta = await supabase
          .from('manutencoes')
          .select()
          .eq('veiculo_id', veiculoId)
          .order('id', ascending: false);

      final listData = List<Map<String, dynamic>>.from(resposta);

      final double kmAtualVeiculo = double.tryParse(widget.veiculo['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
      bool pendente = false;

      for (var m in listData) {
        final double proximaKm = double.tryParse(m['proxima_km']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
        if (proximaKm > 0 && kmAtualVeiculo >= proximaKm) {
          pendente = true;
          break;
        }
      }

      setState(() {
        manutencoes = listData;
        _alertaRevisaoPendente = pendente;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar manutenções: $e')),
        );
      }
    }
  }

  double get _custoTotal {
    double total = 0.0;
    for (var m in manutencoes) {
      final custo = m['custo'];
      if (custo != null) {
        if (custo is num) {
          total += custo.toDouble();
        } else if (custo is String) {
          total += double.tryParse(custo.replaceAll(',', '.')) ?? 0.0;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final placa = widget.veiculo['placa'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Veículo: $modelo ($placa)'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botão de Manutenções no topo igual aos outros
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: 'Controle de Manutenções',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaListaManutencoes(veiculo: widget.veiculo),
                ),
              );
              setState(() => _carregando = true);
              _carregarManutencoes();
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Relatório de Lucro Mensal',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaRelatorioLucro(veiculo: widget.veiculo),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.local_gas_station),
            tooltip: 'Controle de Combustível',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaListaCombustivel(veiculo: widget.veiculo),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.radio_button_checked), // Ícone para Pneus
            tooltip: 'Controle de Pneus',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaListaPneus(veiculo: widget.veiculo),
                ),
              );
              // Recarrega se necessário ao voltar
            },
          ),
          IconButton(
            icon: const Icon(Icons.alt_route),
            tooltip: 'Controle de Viagens',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TelaListaViagens(veiculo: widget.veiculo),
                ),
              );
            },
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_alertaRevisaoPendente)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          '⚠️ ATENÇÃO: Revisão Pendente/Vencida!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custo Total Geral (Manutenções):',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'R\$ ${_custoTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.build_circle, size: 64, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            'Gestão de Manutenções Mensais',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Toque no botão abaixo ou no ícone de chave inglesa no topo para aceder à lista detalhada com filtros por mês e custos mensais.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Abrir Lista de Manutenções por Mês', style: TextStyle(fontSize: 15)),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TelaListaManutencoes(veiculo: widget.veiculo),
                                ),
                              );
                              setState(() => _carregando = true);
                              _carregarManutencoes();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final adicionado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroManutencao(veiculoId: widget.veiculo['id']),
            ),
          );

          if (adicionado == true) {
            setState(() => _carregando = true);
            _carregarManutencoes();
          }
        },
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Manutenção'),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE RELATÓRIO DE LUCRO MENSAL
// ----------------------------------------------------
class TelaRelatorioLucro extends StatefulWidget {
  final Map<String, dynamic> veiculo;

  const TelaRelatorioLucro({super.key, required this.veiculo});

  @override
  State<TelaRelatorioLucro> createState() => _TelaRelatorioLucroState();
}

class _TelaRelatorioLucroState extends State<TelaRelatorioLucro> {
  bool _carregando = true;
  List<Map<String, dynamic>> viagens = [];
  List<Map<String, dynamic>> manutencoes = [];
  List<Map<String, dynamic>> combustivel = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosFinanceiros();
  }

  Future<void> _carregarDadosFinanceiros() async {
    try {
      final veiculoId = widget.veiculo['id'];
      
      final resViagens = await supabase.from('viagens').select().eq('veiculo_id', veiculoId);
      final resManut = await supabase.from('manutencoes').select().eq('veiculo_id', veiculoId);
      final resComb = await supabase.from('combustivel').select().eq('veiculo_id', veiculoId);

      setState(() {
        viagens = List<Map<String, dynamic>>.from(resViagens);
        manutencoes = List<Map<String, dynamic>>.from(resManut);
        combustivel = List<Map<String, dynamic>>.from(resComb);
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados financeiros: $e')),
        );
      }
    }
  }

  String _extrairMesAno(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return 'Outros';
    try {
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        if (partes.length == 3) {
          return '${partes[1]}/${partes[2]}';
        }
      }
    } catch (_) {}
    return 'Outros';
  }

  List<String> get _todosMeses {
    final Set<String> meses = {};
    for (var v in viagens) {
      final m = _extrairMesAno(v['data']?.toString());
      if (m != 'Outros') meses.add(m);
    }
    for (var m in manutencoes) {
      final mes = _extrairMesAno(m['data']?.toString());
      if (mes != 'Outros') meses.add(mes);
    }
    for (var c in combustivel) {
      final mes = _extrairMesAno(c['data']?.toString());
      if (mes != 'Outros') meses.add(mes);
    }
    
    final lista = meses.toList();
    lista.sort((a, b) => b.compareTo(a));
    return lista;
  }

  double _calcularFreteMes(String mesAno) {
    double total = 0.0;
    for (var v in viagens) {
      if (_extrairMesAno(v['data']?.toString()) == mesAno) {
        final frete = v['frete_total'];
        if (frete != null) {
          total += frete is num ? frete.toDouble() : (double.tryParse(frete.toString().replaceAll(',', '.')) ?? 0.0);
        }
      }
    }
    return total;
  }

  double _calcularManutencaoMes(String mesAno) {
    double total = 0.0;
    for (var m in manutencoes) {
      if (_extrairMesAno(m['data']?.toString()) == mesAno) {
        final custo = m['custo'];
        if (custo != null) {
          total += custo is num ? custo.toDouble() : (double.tryParse(custo.toString().replaceAll(',', '.')) ?? 0.0);
        }
      }
    }
    return total;
  }

  double _calcularCombustivelMes(String mesAno) {
    double total = 0.0;
    for (var c in combustivel) {
      if (_extrairMesAno(c['data']?.toString()) == mesAno) {
        final valor = c['valor_total'];
        if (valor != null) {
          total += valor is num ? valor.toDouble() : (double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0.0);
        }
      }
    }
    return total;
  }

  double _calcularKMRodadosMes(String mesAno) {
    double totalKm = 0.0;
    for (var v in viagens) {
      if (_extrairMesAno(v['data']?.toString()) == mesAno) {
        final kmInicial = double.tryParse(v['km_inicial']?.toString() ?? '0') ?? 0.0;
        final kmFinal = double.tryParse(v['km_final']?.toString() ?? '0') ?? 0.0;
        if (kmFinal >= kmInicial) {
          totalKm += (kmFinal - kmInicial);
        }
      }
    }
    return totalKm;
  }

  void _mostrarFaturaMensal(BuildContext context, String mes) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final placa = widget.veiculo['placa'] ?? '';
    final frete = _calcularFreteMes(mes);
    final manut = _calcularManutencaoMes(mes);
    final comb = _calcularCombustivelMes(mes);
    final kmRodados = _calcularKMRodadosMes(mes);
    final totalDespesas = manut + comb;
    final lucro = frete - totalDespesas;
    final custoPorKm = kmRodados > 0 ? totalDespesas / kmRodados : 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaFaturaImpressao(
          modelo: modelo,
          placa: placa,
          mes: mes,
          frete: frete,
          manutencao: manut,
          combustivel: comb,
          kmRodados: kmRodados,
          custoPorKm: custoPorKm,
          lucro: lucro,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final meses = _todosMeses;

    return Scaffold(
      appBar: AppBar(
        title: Text('Relatório de Lucro: $modelo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : meses.isEmpty
              ? const Center(
                  child: Text(
                    'Sem dados suficientes para gerar relatório.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: meses.length,
                  itemBuilder: (context, index) {
                    final mes = meses[index];
                    final frete = _calcularFreteMes(mes);
                    final manut = _calcularManutencaoMes(mes);
                    final comb = _calcularCombustivelMes(mes);
                    final kmRodados = _calcularKMRodadosMes(mes);

                    final totalDespesas = manut + comb;
                    final lucro = frete - totalDespesas;
                    final custoPorKm = kmRodados > 0 ? totalDespesas / kmRodados : 0.0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '📅 Mês: $mes',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                      tooltip: 'Gerar Fatura / PDF do Mês',
                                      onPressed: () => _mostrarFaturaMensal(context, mes),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: lucro >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        lucro >= 0 ? 'LUCRO' : 'PREJUÍZO',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: lucro >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('🟢 Total Fretes (Receita):', style: TextStyle(fontSize: 14)),
                                Text('R\$ ${frete.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('🟠 Manutenções:', style: TextStyle(fontSize: 14)),
                                Text('- R\$ ${manut.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('🔴 Combustível:', style: TextStyle(fontSize: 14)),
                                Text('- R\$ ${comb.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('🛣️ Distância Rodada:', style: TextStyle(fontSize: 14)),
                                Text('${kmRodados.toStringAsFixed(0)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('📉 Custo por KM:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
                                Text(
                                  kmRodados > 0 ? 'R\$ ${custoPorKm.toStringAsFixed(2)}/km' : 'N/D',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '💰 Lucro Líquido:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'R\$ ${lucro.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: lucro >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ----------------------------------------------------
// TELA DE VISUALIZAÇÃO DE FATURA PARA IMPRESSÃO / PDF
// ----------------------------------------------------
class TelaFaturaImpressao extends StatelessWidget {
  final String modelo;
  final String placa;
  final String mes;
  final double frete;
  final double manutencao;
  final double combustivel;
  final double kmRodados;
  final double custoPorKm;
  final double lucro;

  const TelaFaturaImpressao({
    super.key,
    required this.modelo,
    required this.placa,
    required this.mes,
    required this.frete,
    required this.manutencao,
    required this.combustivel,
    required this.kmRodados,
    required this.custoPorKm,
    required this.lucro,
  });

  void _executarImpressao(BuildContext context) {
    if (kIsWeb) {
      html.window.print();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impressão nativa ativada na versão Web/Nuvem.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fatura / Fechamento - Mês $mes'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, size: 28),
            tooltip: 'Imprimir / Salvar como PDF',
            onPressed: () => _executarImpressao(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(32.0),
          color: Colors.white,
          child: ListView(
            children: [
              ElevatedButton.icon(
                onPressed: () => _executarImpressao(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.print),
                label: const Text('IMPRIMIR OU SALVAR COMO PDF (Ctrl + P)'),
              ),
              const SizedBox(height: 20),
              const Text(
                'RELATÓRIO FINANCEIRO DE FROTA',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Fechamento Mensal - Referência: $mes',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 40, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Veículo: $modelo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Placa: $placa', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'DEMONSTRATIVO DE RECEITAS E DESPESAS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(padding: EdgeInsets.all(10.0), child: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(10.0), child: Text('Valor (R\$)', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(10.0), child: Text('(+) Receita Total de Fretes')),
                      Padding(padding: const EdgeInsets.all(10.0), child: Text('R\$ ${frete.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(10.0), child: Text('(-) Custo de Manutenções')),
                      Padding(padding: const EdgeInsets.all(10.0), child: Text('R\$ ${manutencao.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(10.0), child: Text('(-) Gasto com Combustível / Arla')),
                      Padding(padding: const EdgeInsets.all(10.0), child: Text('R\$ ${combustivel.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(10.0), child: Text('KM Rodados no Mês')),
                      Padding(padding: const EdgeInsets.all(10.0), child: Text('${kmRodados.toStringAsFixed(0)} km')),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(padding: EdgeInsets.all(10.0), child: Text('Custo Operacional por KM')),
                      Padding(padding: const EdgeInsets.all(10.0), child: Text('R\$ ${custoPorKm.toStringAsFixed(2)}/km', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lucro >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(color: lucro >= 0 ? Colors.green : Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lucro >= 0 ? 'LUCRO LÍQUIDO DO MÊS:' : 'PREJUÍZO DO MÊS:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: lucro >= 0 ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                    Text(
                      'R\$ ${lucro.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: lucro >= 0 ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('_____________________________________', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('Assinatura do Responsável', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('_____________________________________', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 4),
                      Text('Visto da Gestão / Contabilidade', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE LISTA DE COMBUSTÍVEL
// ----------------------------------------------------
class TelaListaCombustivel extends StatefulWidget {
  final Map<String, dynamic> veiculo;

  const TelaListaCombustivel({super.key, required this.veiculo});

  @override
  State<TelaListaCombustivel> createState() => _TelaListaCombustivelState();
}

class _TelaListaCombustivelState extends State<TelaListaCombustivel> {
  List<Map<String, dynamic>> abastecimentos = [];
  bool _carregando = true;
  String _mesSelecionado = 'Todos';

  @override
  void initState() {
    super.initState();
    _carregarAbastecimentos();
  }

  Future<void> _carregarAbastecimentos() async {
    try {
      final veiculoId = widget.veiculo['id'];
      final resposta = await supabase
          .from('combustivel')
          .select()
          .eq('veiculo_id', veiculoId)
          .order('id', ascending: false);

      setState(() {
        abastecimentos = List<Map<String, dynamic>>.from(resposta);
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar abastecimentos: $e')),
        );
      }
    }
  }

  String _extrairMesAno(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return 'Sem Data';
    try {
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        if (partes.length == 3) {
          return '${partes[1]}/${partes[2]}';
        }
      }
    } catch (_) {}
    return 'Outros';
  }

  List<String> get _listaMeses {
    final Set<String> meses = {'Todos'};
    for (var a in abastecimentos) {
      final mesAno = _extrairMesAno(a['data']?.toString());
      if (mesAno != 'Sem Data' && mesAno != 'Outros') {
        meses.add(mesAno);
      }
    }
    return meses.toList();
  }

  List<Map<String, dynamic>> get _abastecimentosFiltrados {
    if (_mesSelecionado == 'Todos') {
      return abastecimentos;
    }
    return abastecimentos.where((a) => _extrairMesAno(a['data']?.toString()) == _mesSelecionado).toList();
  }

  double get _gastoTotalCombustivel {
    double total = 0.0;
    for (var a in _abastecimentosFiltrados) {
      final valor = a['valor_total'];
      if (valor != null) {
        if (valor is num) {
          total += valor.toDouble();
        } else if (valor is String) {
          total += double.tryParse(valor.replaceAll(',', '.')) ?? 0.0;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final listaMeses = _listaMeses;
    final exibeAbastecimentos = _abastecimentosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: Text('Combustível: $modelo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.teal.shade50,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrar por Mês:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<String>(
                            value: listaMeses.contains(_mesSelecionado) ? _mesSelecionado : 'Todos',
                            items: listaMeses.map((String mes) {
                              return DropdownMenuItem<String>(
                                value: mes,
                                child: Text(mes == 'Todos' ? '📅 Todos os Meses' : '📅 Mês $mes'),
                              );
                            }).toList(),
                            onChanged: (novoValor) {
                              if (novoValor != null) {
                                setState(() {
                                  _mesSelecionado = novoValor;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _mesSelecionado == 'Todos' ? 'Gasto Total:' : 'Gasto do Mês ($_mesSelecionado):',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'R\$ ${_gastoTotalCombustivel.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: exibeAbastecimentos.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum abastecimento registado.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: exibeAbastecimentos.length,
                          itemBuilder: (context, index) {
                            final item = exibeAbastecimentos[index];
                            final kmAtual = double.tryParse(item['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
                            final litros = double.tryParse(item['litros']?.toString() ?? '0') ?? 0.0;
                            final valorTotal = double.tryParse(item['valor_total']?.toString() ?? '0') ?? 0.0;
                            final tipoCombustivel = item['tipo_combustivel'] ?? 'Não informado';
                            final posto = item['posto'] ?? '';

                            final custoLitro = litros > 0 ? valorTotal / litros : 0.0;

                            String kmPorLitroStr = 'N/D';
                            if (index < exibeAbastecimentos.length - 1) {
                              final itemAnterior = exibeAbastecimentos[index + 1];
                              final kmAnterior = double.tryParse(itemAnterior['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
                              if (kmAtual > kmAnterior && litros > 0) {
                                final kmRodados = kmAtual - kmAnterior;
                                final media = kmRodados / litros;
                                kmPorLitroStr = '${media.toStringAsFixed(2)} km/L';
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: Icon(Icons.local_gas_station, color: Colors.white),
                                ),
                                title: Text(
                                  'KM: ${item['quilometragem']} | Data: ${item['data']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Tipo: $tipoCombustivel ${posto.isNotEmpty ? '| Posto: $posto' : ''}'),
                                    Text('Litros: ${litros.toStringAsFixed(1)} L  |  Preço/L: R\$ ${custoLitro.toStringAsFixed(2)}'),
                                    Text(
                                      'Média: $kmPorLitroStr',
                                      style: const TextStyle(
                                        color: Colors.teal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'R\$ ${valorTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                                  ],
                                ),
                                onTap: () async {
                                  final atualizado = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TelaCadastroCombustivel(
                                        veiculoId: widget.veiculo['id'],
                                        abastecimentoExistente: item,
                                      ),
                                    ),
                                  );

                                  if (atualizado == true) {
                                    setState(() => _carregando = true);
                                    _carregarAbastecimentos();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final adicionado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroCombustivel(veiculoId: widget.veiculo['id']),
            ),
          );

          if (adicionado == true) {
            setState(() => _carregando = true);
            _carregarAbastecimentos();
          }
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Abastecimento'),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE CADASTRO DE COMBUSTÍVEL
// ----------------------------------------------------
class TelaCadastroCombustivel extends StatefulWidget {
  final dynamic veiculoId;
  final Map<String, dynamic>? abastecimentoExistente;

  const TelaCadastroCombustivel({
    super.key,
    required this.veiculoId,
    this.abastecimentoExistente,
  });

  @override
  State<TelaCadastroCombustivel> createState() => _TelaCadastroCombustivelState();
}

class _TelaCadastroCombustivelState extends State<TelaCadastroCombustivel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kmController;
  late final TextEditingController _litrosController;
  late final TextEditingController _valorTotalController;
  late final TextEditingController _postoController;
  late final TextEditingController _dataController;
  
  String _tipoCombustivel = 'Diesel S10';
  final List<String> _opcoesTipo = [
    'Diesel S10',
    'Arla 32',
    'Diesel S500',
    'Gasolina',
    'Etanol',
    'Outro',
  ];

  bool _aSalvar = false;

  @override
  void initState() {
    super.initState();
    final a = widget.abastecimentoExistente;
    _kmController = TextEditingController(text: a != null ? a['quilometragem']?.toString() : '');
    _litrosController = TextEditingController(text: a != null ? a['litros']?.toString() : '');
    _valorTotalController = TextEditingController(text: a != null ? a['valor_total']?.toString() : '');
    _postoController = TextEditingController(text: a != null ? a['posto']?.toString() : '');
    
    if (a != null && a['tipo_combustivel'] != null && _opcoesTipo.contains(a['tipo_combustivel'])) {
      _tipoCombustivel = a['tipo_combustivel'];
    }

    _dataController = TextEditingController(
      text: a != null
          ? a['data']
          : '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
  }

  @override
  void dispose() {
    _kmController.dispose();
    _litrosController.dispose();
    _valorTotalController.dispose();
    _postoController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _salvarCombustivel() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _aSalvar = true);

      try {
        final kmDigitado = _kmController.text.trim();
        final dados = {
          'veiculo_id': widget.veiculoId,
          'quilometragem': kmDigitado,
          'litros': double.parse(_litrosController.text.trim().replaceAll(',', '.')),
          'valor_total': double.parse(_valorTotalController.text.trim().replaceAll(',', '.')),
          'tipo_combustivel': _tipoCombustivel,
          'posto': _postoController.text.trim().isNotEmpty ? _postoController.text.trim() : null,
          'data': _dataController.text.trim(),
        };

        if (widget.abastecimentoExistente == null) {
          await supabase.from('combustivel').insert(dados);
        } else {
          final id = widget.abastecimentoExistente!['id'];
          await supabase.from('combustivel').update(dados).eq('id', id);
        }

        // Atualiza a KM do veículo automaticamente no banco se a nova KM for maior
        await _atualizarKmVeiculoSeMaior(widget.veiculoId, kmDigitado);

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() => _aSalvar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar abastecimento: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editando = widget.abastecimentoExistente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar Abastecimento' : 'Registar Abastecimento'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _tipoCombustivel,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Combustível (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.opacity),
                ),
                items: _opcoesTipo.map((String opcao) {
                  return DropdownMenuItem<String>(
                    value: opcao,
                    child: Text(opcao),
                  );
                }).toList(),
                onChanged: (novoVal) {
                  if (novoVal != null) {
                    setState(() => _tipoCombustivel = novoVal);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _postoController,
                decoration: const InputDecoration(
                  labelText: 'Posto / Local do Abastecimento (Opcional)',
                  hintText: 'Ex: Posto Graal / Posto Shell',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _kmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quilometragem Atual',
                  hintText: 'Ex: 110500',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe a quilometragem'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _litrosController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantidade em Litros',
                  hintText: 'Ex: 50.5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_gas_station),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe os litros'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valorTotalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor Total (R\$)',
                  hintText: 'Ex: 300.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe o valor total'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  hintText: 'DD/MM/AAAA',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe a data'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _aSalvar ? null : _salvarCombustivel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _aSalvar
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _aSalvar ? 'A guardar...' : (editando ? 'Atualizar Abastecimento' : 'Salvar Abastecimento'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE LISTA DE VIAGENS (OTIMIZADA PARA TELEMÓVEL)
// ----------------------------------------------------
class TelaListaViagens extends StatefulWidget {
  final Map<String, dynamic> veiculo;

  const TelaListaViagens({super.key, required this.veiculo});

  @override
  State<TelaListaViagens> createState() => _TelaListaViagensState();
}

class _TelaListaViagensState extends State<TelaListaViagens> {
  List<Map<String, dynamic>> viagens = [];
  bool _carregando = true;
  String _mesSelecionado = 'Todos';

  @override
  void initState() {
    super.initState();
    _carregarViagens();
  }

  Future<void> _carregarViagens() async {
    try {
      final veiculoId = widget.veiculo['id'];
      final resposta = await supabase
          .from('viagens')
          .select()
          .eq('veiculo_id', veiculoId)
          .order('id', ascending: false);

      setState(() {
        viagens = List<Map<String, dynamic>>.from(resposta);
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar viagens: $e')),
        );
      }
    }
  }

  String _extrairMesAno(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return 'Sem Data';
    try {
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        if (partes.length == 3) {
          return '${partes[1]}/${partes[2]}';
        }
      }
    } catch (_) {}
    return 'Outros';
  }

  List<String> get _listaMeses {
    final Set<String> meses = {'Todos'};
    for (var v in viagens) {
      final mesAno = _extrairMesAno(v['data']?.toString());
      if (mesAno != 'Sem Data' && mesAno != 'Outros') {
        meses.add(mesAno);
      }
    }
    return meses.toList();
  }

  List<Map<String, dynamic>> get _viagensFiltradas {
    if (_mesSelecionado == 'Todos') {
      return viagens;
    }
    return viagens.where((v) => _extrairMesAno(v['data']?.toString()) == _mesSelecionado).toList();
  }

  double get _freteTotalGeral {
    double total = 0.0;
    for (var v in _viagensFiltradas) {
      final frete = v['frete_total'];
      if (frete != null) {
        if (frete is num) {
          total += frete.toDouble();
        } else if (frete is String) {
          total += double.tryParse(frete.replaceAll(',', '.')) ?? 0.0;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final listaMeses = _listaMeses;
    final exibeViagens = _viagensFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: Text('Viagens: $modelo'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.indigo.shade50,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrar por Mês:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<String>(
                            value: listaMeses.contains(_mesSelecionado) ? _mesSelecionado : 'Todos',
                            items: listaMeses.map((String mes) {
                              return DropdownMenuItem<String>(
                                value: mes,
                                child: Text(mes == 'Todos' ? '📅 Todos os Meses' : '📅 Mês $mes'),
                              );
                            }).toList(),
                            onChanged: (novoValor) {
                              if (novoValor != null) {
                                setState(() {
                                  _mesSelecionado = novoValor;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _mesSelecionado == 'Todos' ? 'Frete Total Geral:' : 'Frete do Mês ($_mesSelecionado):',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'R\$ ${_freteTotalGeral.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: exibeViagens.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma viagem encontrada para este período.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: exibeViagens.length,
                          itemBuilder: (context, index) {
                            final item = exibeViagens[index];
                            final kmInicial = int.tryParse(item['km_inicial']?.toString() ?? '0') ?? 0;
                            final kmFinal = int.tryParse(item['km_final']?.toString() ?? '0') ?? 0;
                            final kmRodados = kmFinal >= kmInicial ? kmFinal - kmInicial : 0;
                            final freteTotal = double.tryParse(item['frete_total']?.toString() ?? '0') ?? 0.0;
                            
                            final adiantamento = double.tryParse(item['adiantamento']?.toString() ?? '0') ?? 0.0;
                            final saldoRecebido = double.tryParse(item['saldo_recebido']?.toString() ?? '0') ?? 0.0;
                            final valePedagio = double.tryParse(item['vale_pedagio']?.toString() ?? '0') ?? 0.0;
                            final tarifas = double.tryParse(item['tarifas']?.toString() ?? '0') ?? 0.0;
                            
                            final restantePendente = freteTotal - adiantamento - saldoRecebido - valePedagio - tarifas;

                            final bool quitado = restantePendente <= 0 && freteTotal > 0;
                            final Color corEstado = quitado ? Colors.green : Colors.orange.shade800;
                            final String textoEstado = quitado ? 'Quitado' : 'Pendente';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetalhesViagemAbasScreen(viagem: item),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Linha Superior: Origem ➔ Destino e Status
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item['origem'] ?? ''} ➔ ${item['destino'] ?? ''}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: corEstado.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: corEstado),
                                            ),
                                            child: Text(
                                              textoEstado,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: corEstado),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      // Linha do Meio: Detalhes da Viagem
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Data: ${item['data'] ?? '-'}', style: const TextStyle(fontSize: 13)),
                                              const SizedBox(height: 2),
                                              Text('Motorista: ${item['motorista'] ?? 'Não informado'}', style: const TextStyle(fontSize: 13)),
                                              const SizedBox(height: 2),
                                              Text('Distância: $kmRodados km ($kmInicial ➔ $kmFinal)', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                              if (item['produto'] != null && item['produto'].toString().isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text('Produto: ${item['produto']}', style: const TextStyle(fontSize: 13, color: Colors.indigo)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Linha Inferior: Valor do Frete e Botão de Editar
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Frete Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text(
                                                'R\$ ${freteTotal.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.edit, size: 16, color: Colors.indigo),
                                            label: const Text('Editar', style: TextStyle(color: Colors.indigo, fontSize: 13)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              side: const BorderSide(color: Colors.indigo),
                                            ),
                                            onPressed: () async {
                                              final atualizado = await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => TelaCadastroViagem(
                                                    veiculoId: widget.veiculo['id'],
                                                    viagemExistente: item,
                                                  ),
                                                ),
                                              );

                                              if (atualizado == true) {
                                                setState(() => _carregando = true);
                                                _carregarViagens();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final adicionado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroViagem(veiculoId: widget.veiculo['id']),
            ),
          );

          if (adicionado == true) {
            setState(() => _carregando = true);
            _carregarViagens();
          }
        },
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Viagem'),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE CADASTRO OU EDIÇÃO DE VIAGEM (COM PEDÁGIO E TARIFAS)
// ----------------------------------------------------
class TelaCadastroViagem extends StatefulWidget {
  final dynamic veiculoId;
  final Map<String, dynamic>? viagemExistente;

  const TelaCadastroViagem({
    super.key,
    required this.veiculoId,
    this.viagemExistente,
  });

  @override
  State<TelaCadastroViagem> createState() => _TelaCadastroViagemState();
}

class _TelaCadastroViagemState extends State<TelaCadastroViagem> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _origemController;
  late final TextEditingController _destinoController;
  late final TextEditingController _kmInicialController;
  late final TextEditingController _kmFinalController;
  late final TextEditingController _toneladasController;
  late final TextEditingController _valorTonController;
  late final TextEditingController _motoristaController;
  late final TextEditingController _produtoController;
  late final TextEditingController _transportadoraController;
  late final TextEditingController _dataController;
  
  // CONTROLADORES FINANCEIROS (Adiantamento, Saldo, Pedágio, Tarifas)
  late final TextEditingController _adiantamentoController;
  late final TextEditingController _dataAdiantamentoController;
  late final TextEditingController _saldoRecebidoController;
  late final TextEditingController _dataSaldoController;
  late final TextEditingController _valePedagioController;
  late final TextEditingController _dataPedagioController;
  late final TextEditingController _tarifasController;
  late final TextEditingController _dataTarifasController;
  
  bool _aSalvar = false;

  @override
  void initState() {
    super.initState();
    final v = widget.viagemExistente;
    _origemController = TextEditingController(text: v != null ? v['origem'] : '');
    _destinoController = TextEditingController(text: v != null ? v['destino'] : '');
    _kmInicialController = TextEditingController(text: v != null ? v['km_inicial']?.toString() : '');
    _kmFinalController = TextEditingController(text: v != null ? v['km_final']?.toString() : '');
    _toneladasController = TextEditingController(text: v != null ? v['toneladas']?.toString() : '');
    _valorTonController = TextEditingController(text: v != null ? v['valor_tonelada']?.toString() : '');
    _motoristaController = TextEditingController(text: v != null ? v['motorista']?.toString() : '');
    _produtoController = TextEditingController(text: v != null ? v['produto']?.toString() : '');
    _transportadoraController = TextEditingController(text: v != null ? v['transportadora']?.toString() : '');
    
    // INICIALIZAÇÃO DOS CAMPOS FINANCEIROS
    _adiantamentoController = TextEditingController(text: v != null ? v['adiantamento']?.toString() : '');
    _dataAdiantamentoController = TextEditingController(text: v != null ? v['data_adiantamento']?.toString() : '');
    _saldoRecebidoController = TextEditingController(text: v != null ? v['saldo_recebido']?.toString() : '');
    _dataSaldoController = TextEditingController(text: v != null ? v['data_saldo']?.toString() : '');
    _valePedagioController = TextEditingController(text: v != null ? v['vale_pedagio']?.toString() : '');
    _dataPedagioController = TextEditingController(text: v != null ? v['data_pedagio']?.toString() : '');
    _tarifasController = TextEditingController(text: v != null ? v['tarifas']?.toString() : '');
    _dataTarifasController = TextEditingController(text: v != null ? v['data_tarifas']?.toString() : '');

    _dataController = TextEditingController(
      text: v != null
          ? v['data']
          : '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
  }

  @override
  void dispose() {
    _origemController.dispose();
    _destinoController.dispose();
    _kmInicialController.dispose();
    _kmFinalController.dispose();
    _toneladasController.dispose();
    _valorTonController.dispose();
    _motoristaController.dispose();
    _produtoController.dispose();
    _transportadoraController.dispose();
    _adiantamentoController.dispose();
    _dataAdiantamentoController.dispose();
    _saldoRecebidoController.dispose();
    _dataSaldoController.dispose();
    _valePedagioController.dispose();
    _dataPedagioController.dispose();
    _tarifasController.dispose();
    _dataTarifasController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _salvarViagem() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _aSalvar = true);

      try {
        final kmFinalStr = _kmFinalController.text.trim();
        final toneladas = double.tryParse(_toneladasController.text.trim().replaceAll(',', '.')) ?? 0.0;
        final valorTon = double.tryParse(_valorTonController.text.trim().replaceAll(',', '.')) ?? 0.0;
        final freteTotal = toneladas * valorTon;
        
        final adiantamentoVal = double.tryParse(_adiantamentoController.text.trim().replaceAll(',', '.')) ?? 0.0;
        final saldoRecebidoVal = double.tryParse(_saldoRecebidoController.text.trim().replaceAll(',', '.')) ?? 0.0;
        final valePedagioVal = double.tryParse(_valePedagioController.text.trim().replaceAll(',', '.')) ?? 0.0;
        final tarifasVal = double.tryParse(_tarifasController.text.trim().replaceAll(',', '.')) ?? 0.0;

        final dados = {
          'veiculo_id': widget.veiculoId,
          'origem': _origemController.text.trim(),
          'destino': _destinoController.text.trim(),
          'km_inicial': _kmInicialController.text.trim(),
          'km_final': kmFinalStr,
          'toneladas': toneladas > 0 ? toneladas : null,
          'valor_tonelada': valorTon > 0 ? valorTon : null,
          'frete_total': freteTotal > 0 ? freteTotal : null,
          'motorista': _motoristaController.text.trim(),
          'produto': _produtoController.text.trim(),
          'transportadora': _transportadoraController.text.trim(),
          'adiantamento': adiantamentoVal,
          'data_adiantamento': _dataAdiantamentoController.text.trim(),
          'saldo_recebido': saldoRecebidoVal,
          'data_saldo': _dataSaldoController.text.trim(),
          'vale_pedagio': valePedagioVal,
          'data_pedagio': _dataPedagioController.text.trim(),
          'tarifas': tarifasVal,
          'data_tarifas': _dataTarifasController.text.trim(),
          'data': _dataController.text.trim(),
        };

        if (widget.viagemExistente == null) {
          await supabase.from('viagens').insert(dados);
        } else {
          final id = widget.viagemExistente!['id'];
          await supabase.from('viagens').update(dados).eq('id', id);
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() => _aSalvar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar viagem: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editando = widget.viagemExistente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar Viagem' : 'Registar Viagem'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _origemController,
                decoration: const InputDecoration(
                  labelText: 'Origem',
                  hintText: 'Ex: Fazenda / Armazém',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trip_origin),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Informe a origem' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _destinoController,
                decoration: const InputDecoration(
                  labelText: 'Destino',
                  hintText: 'Ex: Porto / Terminal',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Informe o destino' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kmInicialController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'KM Inicial',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Informe o KM inicial' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _kmFinalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'KM Final',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Informe o KM final' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _toneladasController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Peso (Ton)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _valorTonController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor por Tonelada (R\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _produtoController,
                decoration: const InputDecoration(
                  labelText: 'Produto / Grão',
                  hintText: 'Ex: Soja, Milho',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _transportadoraController,
                decoration: const InputDecoration(
                  labelText: 'Transportadora',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping),
                ),
              ),
              
              // SEÇÃO DE CONTROLOS FINANCEIROS
              const SizedBox(height: 24),
              const Text('Controlo Financeiro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 12),
              
              // Adiantamento
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _adiantamentoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Adiantamento (R\$)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dataAdiantamentoController,
                      decoration: const InputDecoration(labelText: 'Data Adiantamento', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Saldo
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _saldoRecebidoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Saldo Recebido (R\$)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dataSaldoController,
                      decoration: const InputDecoration(labelText: 'Data Saldo', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vale Pedágio
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valePedagioController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Vale Pedágio (R\$)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dataPedagioController,
                      decoration: const InputDecoration(labelText: 'Data Pedágio', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tarifas
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tarifasController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tarifas (R\$)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dataTarifasController,
                      decoration: const InputDecoration(labelText: 'Data Tarifas', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _motoristaController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Motorista (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data da Viagem',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Informe a data' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _aSalvar ? null : _salvarViagem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _aSalvar
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _aSalvar ? 'A guardar...' : (editando ? 'Atualizar Viagem' : 'Salvar Viagem'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE CADASTRO DE MANUTENÇÃO
// ----------------------------------------------------
class TelaCadastroManutencao extends StatefulWidget {
  final dynamic veiculoId;
  final Map<String, dynamic>? manutencaoExistente;

  const TelaCadastroManutencao({
    super.key,
    required this.veiculoId,
    this.manutencaoExistente,
  });

  @override
  State<TelaCadastroManutencao> createState() => _TelaCadastroManutencaoState();
}

class _TelaCadastroManutencaoState extends State<TelaCadastroManutencao> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricaoController;
  late final TextEditingController _custoController;
  late final TextEditingController _kmController;
  late final TextEditingController _proximaKmController;
  late final TextEditingController _dataController;
  bool _aSalvar = false;

  @override
  void initState() {
    super.initState();
    final m = widget.manutencaoExistente;
    _descricaoController = TextEditingController(text: m != null ? m['descricao'] : '');
    _custoController = TextEditingController(text: m != null ? m['custo'].toString() : '');
    _kmController = TextEditingController(text: m != null ? m['quilometragem']?.toString() : '');
    _proximaKmController = TextEditingController(text: m != null ? m['proxima_km']?.toString() : '');
    _dataController = TextEditingController(
      text: m != null
          ? m['data']
          : '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
    );
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _custoController.dispose();
    _kmController.dispose();
    _proximaKmController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _salvarManutencao() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _aSalvar = true);

      try {
        final kmServico = _kmController.text.trim();
        final dados = {
          'veiculo_id': widget.veiculoId,
          'descricao': _descricaoController.text.trim(),
          'custo': double.parse(_custoController.text.trim().replaceAll(',', '.')),
          'quilometragem': kmServico,
          'proxima_km': _proximaKmController.text.trim(),
          'data': _dataController.text.trim(),
        };

        if (widget.manutencaoExistente == null) {
          await supabase.from('manutencoes').insert(dados);
        } else {
          final id = widget.manutencaoExistente!['id'];
          await supabase.from('manutencoes').update(dados).eq('id', id);
        }

        // Atualiza a KM do veículo automaticamente no banco se a nova KM do serviço for maior
        await _atualizarKmVeiculoSeMaior(widget.veiculoId, kmServico);

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() => _aSalvar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar manutenção: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editando = widget.manutencaoExistente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar Manutenção' : 'Registar Manutenção'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição do Serviço',
                  hintText: 'Ex: Troca de óleo e filtros',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build_circle),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe a descrição'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _custoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Custo (R\$)',
                  hintText: 'Ex: 350.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe o custo'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _kmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quilometragem no Serviço',
                  hintText: 'Ex: 228000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe a quilometragem atual do serviço'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _proximaKmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'KM da Próxima Revisão (Opcional)',
                  hintText: 'Ex: 238000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.update),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dataController,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  hintText: 'DD/MM/AAAA',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Por favor, informe a data'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _aSalvar ? null : _salvarManutencao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _aSalvar
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _aSalvar ? 'A guardar...' : (editando ? 'Atualizar Manutenção' : 'Salvar Manutenção'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE LISTA DE MANUTENÇÕES (COM FILTRO MENSAL E PESQUISA)
// ----------------------------------------------------
class TelaListaManutencoes extends StatefulWidget {
  final Map<String, dynamic> veiculo;

  const TelaListaManutencoes({super.key, required this.veiculo});

  @override
  State<TelaListaManutencoes> createState() => _TelaListaManutencoesState();
}

class _TelaListaManutencoesState extends State<TelaListaManutencoes> {
  List<Map<String, dynamic>> manutencoes = [];
  bool _carregando = true;
  String _mesSelecionado = 'Todos';
  final TextEditingController _pesquisaController = TextEditingController();
  bool _alertaRevisaoPendente = false;

  @override
  void initState() {
    super.initState();
    _carregarManutencoes();
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _carregarManutencoes() async {
    try {
      final veiculoId = widget.veiculo['id'];
      final resposta = await supabase
          .from('manutencoes')
          .select()
          .eq('veiculo_id', veiculoId)
          .order('id', ascending: false);

      final lista = List<Map<String, dynamic>>.from(resposta);
      
      final kmAtualVeiculo = double.tryParse(widget.veiculo['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
      bool temAlerta = false;
      for (var m in lista) {
        final proxima = double.tryParse(m['proxima_km']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
        if (proxima > 0 && kmAtualVeiculo >= proxima) {
          temAlerta = true;
          break;
        }
      }

      setState(() {
        manutencoes = lista;
        _alertaRevisaoPendente = temAlerta;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar manutenções: $e')),
        );
      }
    }
  }

  String _extrairMesAno(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return 'Sem Data';
    try {
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        if (partes.length == 3) {
          return '${partes[1]}/${partes[2]}';
        }
      }
    } catch (_) {}
    return 'Outros';
  }

  List<String> get _listaMeses {
    final Set<String> meses = {'Todos'};
    for (var m in manutencoes) {
      final mesAno = _extrairMesAno(m['data']?.toString());
      if (mesAno != 'Sem Data' && mesAno != 'Outros') {
        meses.add(mesAno);
      }
    }
    return meses.toList();
  }

  List<Map<String, dynamic>> get _manutencoesFiltradas {
    return manutencoes.where((m) {
      // Filtro por Mês
      final mesAno = _extrairMesAno(m['data']?.toString());
      final passaMes = (_mesSelecionado == 'Todos' || mesAno == _mesSelecionado);

      // Filtro por Texto de Pesquisa (descrição)
      final termoPesquisa = _pesquisaController.text.trim().toLowerCase();
      final descricao = (m['descricao'] ?? '').toString().toLowerCase();
      final passaTexto = termoPesquisa.isEmpty || descricao.contains(termoPesquisa);

      return passaMes && passaTexto;
    }).toList();
  }

  double get _custoTotalFiltrado {
    double total = 0.0;
    for (var m in _manutencoesFiltradas) {
      final custo = m['custo'];
      if (custo != null) {
        if (custo is num) {
          total += custo.toDouble();
        } else if (custo is String) {
          total += double.tryParse(custo.replaceAll(',', '.')) ?? 0.0;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final listaMeses = _listaMeses;
    final exibeManutencoes = _manutencoesFiltradas;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manutenções: $modelo'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_alertaRevisaoPendente)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          '⚠️ ATENÇÃO: Revisão Pendente/Vencida!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.orange.shade50,
                  child: Column(
                    children: [
                      // Barra de Pesquisa por Texto
                      TextField(
                        controller: _pesquisaController,
                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar descrição (ex: pátio, óleo, filtro)...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _pesquisaController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _pesquisaController.clear();
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrar por Mês:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<String>(
                            value: listaMeses.contains(_mesSelecionado) ? _mesSelecionado : 'Todos',
                            items: listaMeses.map((String mes) {
                              return DropdownMenuItem<String>(
                                value: mes,
                                child: Text(mes == 'Todos' ? '📅 Todos os Meses' : '📅 Mês $mes'),
                              );
                            }).toList(),
                            onChanged: (novoValor) {
                              if (novoValor != null) {
                                setState(() {
                                  _mesSelecionado = novoValor;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _mesSelecionado == 'Todos' && _pesquisaController.text.isEmpty
                                ? 'Custo Total Geral:'
                                : 'Custo Filtrado:',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'R\$ ${_custoTotalFiltrado.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: exibeManutencoes.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma manutenção encontrada com estes filtros.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: exibeManutencoes.length,
                          itemBuilder: (context, index) {
                            final item = exibeManutencoes[index];
                            final proximaKm = item['proxima_km'];
                            final custo = double.tryParse(item['custo']?.toString() ?? '0') ?? 0.0;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Icon(Icons.build, color: Colors.white),
                                ),
                                title: Text(
                                  item['descricao'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Data: ${item['data']} | KM: ${item['quilometragem']}'),
                                    if (proximaKm != null && proximaKm.toString().isNotEmpty)
                                      Text(
                                        'Próxima Revisão: $proximaKm km',
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: proximaKm != null && proximaKm.toString().isNotEmpty,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'R\$ ${custo.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                                  ],
                                ),
                                onTap: () async {
                                  final atualizado = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TelaCadastroManutencao(
                                        veiculoId: widget.veiculo['id'],
                                        manutencaoExistente: item,
                                      ),
                                    ),
                                  );

                                  if (atualizado == true) {
                                    setState(() => _carregando = true);
                                    _carregarManutencoes();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final adicionado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroManutencao(veiculoId: widget.veiculo['id']),
            ),
          );

          if (adicionado == true) {
            setState(() => _carregando = true);
            _carregarManutencoes();
          }
        },
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Manutenção'),
      ),
    );
  }
}

// ==========================================
// TELA DE CADASTRO DE VEÍCULO
// ==========================================
class TelaCadastroVeiculo extends StatefulWidget {
  const TelaCadastroVeiculo({super.key});

  @override
  State<TelaCadastroVeiculo> createState() => _TelaCadastroVeiculoState();
}

class _TelaCadastroVeiculoState extends State<TelaCadastroVeiculo> {
  final _formKey = GlobalKey<FormState>();
  final _modeloController = TextEditingController();
  final _placaController = TextEditingController();
  final _kmController = TextEditingController();
  bool _aSalvar = false;

  @override
  void dispose() {
    _modeloController.dispose();
    _placaController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _salvarVeiculo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _aSalvar = true);

    try {
      await supabase.from('veiculos').insert({
        'modelo': _modeloController.text.trim(),
        'placa': _placaController.text.trim().toUpperCase(),
        'km_atual': int.tryParse(_kmController.text.trim()) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veículo cadastrado com sucesso!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar veículo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _aSalvar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Veículo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _modeloController,
                decoration: const InputDecoration(
                  labelText: 'Modelo do Veículo',
                  hintText: 'Ex: Volvo FH 540',
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Por favor, informe o modelo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placaController,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  hintText: 'Ex: ABC1D23',
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Por favor, informe a placa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _kmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'KM Atual',
                  hintText: 'Ex: 150000',
                ),
                validator: (valor) {
                  if (valor == null || valor.isEmpty) {
                    return 'Por favor, informe a quilometragem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _aSalvar ? null : _salvarVeiculo,
                child: _aSalvar
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvar Veículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================
// TELA DE DETALHES DA VIAGEM COM 5 ABAS (CORRIGIDA)
// ====================================================
class DetalhesViagemAbasScreen extends StatelessWidget {
  final Map<String, dynamic> viagem;

  const DetalhesViagemAbasScreen({super.key, required this.viagem});

  @override
  Widget build(BuildContext context) {
    final double freteTotal = double.tryParse(viagem['frete_total']?.toString() ?? '0') ?? 0.0;
    
    // Valores e Datas
    final double adiantamento = double.tryParse(viagem['adiantamento']?.toString() ?? '0') ?? 0.0;
    final String dataAdiantamento = viagem['data_adiantamento']?.toString().isNotEmpty == true ? viagem['data_adiantamento'] : 'Não informada';

    final double saldoRecebido = double.tryParse(viagem['saldo_recebido']?.toString() ?? '0') ?? 0.0;
    final String dataSaldo = viagem['data_saldo']?.toString().isNotEmpty == true ? viagem['data_saldo'] : 'Não informada';

    final double valePedagio = double.tryParse(viagem['vale_pedagio']?.toString() ?? '0') ?? 0.0;
    final String dataPedagio = viagem['data_pedagio']?.toString().isNotEmpty == true ? viagem['data_pedagio'] : 'Não informada';

    final double tarifas = double.tryParse(viagem['tarifas']?.toString() ?? '0') ?? 0.0;
    final String dataTarifas = viagem['data_tarifas']?.toString().isNotEmpty == true ? viagem['data_tarifas'] : 'Não informada';

    // Saldo restante a receber
    final double restantePendente = freteTotal - adiantamento - saldoRecebido;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${viagem['origem'] ?? 'Origem'} ➔ ${viagem['destino'] ?? 'Destino'}'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'Resumo'),
              Tab(icon: Icon(Icons.money_off), text: 'Adiantamento'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Saldo'),
              Tab(icon: Icon(Icons.toll), text: 'Pedágio'),
              Tab(icon: Icon(Icons.receipt), text: 'Tarifas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ==========================================
            // ABA 1: RESUMO DO FRETE
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informações da Carga e Trajeto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const Divider(height: 24),
                          ListTile(dense: true, title: const Text('Produto / Grão'), subtitle: Text(viagem['produto'] ?? 'Não informado', style: const TextStyle(fontWeight: FontWeight.w600))),
                          ListTile(dense: true, title: const Text('Transportadora'), subtitle: Text(viagem['transportadora'] ?? 'Não informada', style: const TextStyle(fontWeight: FontWeight.w600))),
                          ListTile(dense: true, title: const Text('Motorista'), subtitle: Text(viagem['motorista'] ?? 'Não informado', style: const TextStyle(fontWeight: FontWeight.w600))),
                          ListTile(dense: true, title: const Text('Data da Viagem'), subtitle: Text(viagem['data'] ?? 'N/D', style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumo Financeiro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const Divider(height: 24),
                          ListTile(title: const Text('Frete Total'), trailing: Text('R\$ ${freteTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))),
                          ListTile(title: const Text('Adiantamento'), trailing: Text('R\$ ${adiantamento.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16))),
                          ListTile(title: const Text('Saldo Recebido'), trailing: Text('R\$ ${saldoRecebido.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16))),
                          ListTile(title: const Text('Vale Pedágio'), trailing: Text('R\$ ${valePedagio.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800, fontSize: 16))),
                          ListTile(title: const Text('Tarifas'), trailing: Text('R\$ ${tarifas.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // ABA 2: ADIANTAMENTO
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.money_off, size: 48, color: Colors.amber),
                        const SizedBox(height: 16),
                        const Text('Registo de Adiantamento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const Divider(height: 32),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Valor:', style: TextStyle(fontSize: 16)), Text('R\$ ${adiantamento.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Data do Pagamento:', style: TextStyle(fontSize: 16)), Text(dataAdiantamento, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==========================================
// ABA 3: SALDO (COM DESCONTO COMPLETO)
// ==========================================
Padding(
  padding: const EdgeInsets.all(16.0),
  child: Center(
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fechamento de Saldo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Frete Total:', style: TextStyle(fontSize: 15)), Text('R\$ ${freteTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('(-) Adiantamento:', style: TextStyle(fontSize: 15)), Text('R\$ ${adiantamento.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, color: Colors.red))]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('(-) Saldo Recebido:', style: TextStyle(fontSize: 15)), Text('R\$ ${saldoRecebido.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, color: Colors.blue))]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('(-) Vale Pedágio:', style: TextStyle(fontSize: 15)), Text('R\$ ${valePedagio.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, color: Colors.amber.shade800))]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('(-) Tarifas:', style: TextStyle(fontSize: 15)), Text('R\$ ${tarifas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, color: Colors.purple))]),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Restante a Receber:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  'R\$ ${restantePendente.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: restantePendente > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
),

            // ==========================================
            // ABA 4: VALE PEDÁGIO
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.toll, size: 48, color: Colors.amber),
                        const SizedBox(height: 16),
                        const Text('Registo de Vale Pedágio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const Divider(height: 32),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Valor do Pedágio:', style: TextStyle(fontSize: 16)), Text('R\$ ${valePedagio.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber.shade800))]),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Data:', style: TextStyle(fontSize: 16)), Text(dataPedagio, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==========================================
            // ABA 5: TARIFAS
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt, size: 48, color: Colors.purple),
                        const SizedBox(height: 16),
                        const Text('Registo de Tarifas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const Divider(height: 32),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Valor das Tarifas:', style: TextStyle(fontSize: 16)), Text('R\$ ${tarifas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple))]),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Data:', style: TextStyle(fontSize: 16)), Text(dataTarifas, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE LISTA DE PNEUS DO VEÍCULO
// ----------------------------------------------------
class TelaListaPneus extends StatefulWidget {
  final Map<String, dynamic> veiculo;

  const TelaListaPneus({super.key, required this.veiculo});

  @override
  State<TelaListaPneus> createState() => _TelaListaPneusState();
}

class _TelaListaPneusState extends State<TelaListaPneus> {
  List<Map<String, dynamic>> pneus = [];
  bool _carregando = true;
  String _filtroStatus = 'Todos';
  final TextEditingController _pesquisaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarPneus();
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _carregarPneus() async {
    try {
      final veiculoId = widget.veiculo['id'];
      final resposta = await supabase
          .from('pneus')
          .select()
          .eq('veiculo_id', veiculoId)
          .order('id', ascending: false);

      setState(() {
        pneus = List<Map<String, dynamic>>.from(resposta);
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar pneus: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _pneusFiltrados {
    final kmAtualVeiculo = double.tryParse(widget.veiculo['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;

    return pneus.where((p) {
      // Filtro por Status
      final status = p['status'] ?? 'Em uso';
      final passaStatus = (_filtroStatus == 'Todos' || status == _filtroStatus);

      // Filtro por Texto (Número de Fogo, Marca ou Posição)
      final termo = _pesquisaController.text.trim().toLowerCase();
      final numeroFogo = (p['numero_fogo'] ?? '').toString().toLowerCase();
      final marca = (p['marca'] ?? '').toString().toLowerCase();
      final posicao = (p['posicao'] ?? '').toString().toLowerCase();
      
      final passaTexto = termo.isEmpty || 
          numeroFogo.contains(termo) || 
          marca.contains(termo) || 
          posicao.contains(termo);

      return passaStatus && passaTexto;
    }).toList();
  }

  double get _custoTotalPneus {
    double total = 0.0;
    for (var p in _pneusFiltrados) {
      final custo = p['custo'];
      if (custo != null) {
        if (custo is num) {
          total += custo.toDouble();
        } else if (custo is String) {
          total += double.tryParse(custo.replaceAll(',', '.')) ?? 0.0;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final modelo = widget.veiculo['modelo'] ?? 'Veículo';
    final listaExibida = _pneusFiltrados;
    final kmAtualVeiculo = double.tryParse(widget.veiculo['quilometragem']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Controle de Pneus: $modelo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Column(
                    children: [
                      // Barra de Pesquisa
                      TextField(
                        controller: _pesquisaController,
                        onChanged: (value) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar nº fogo, marca, posição...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _pesquisaController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _pesquisaController.clear()),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrar por Status:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<String>(
                            value: _filtroStatus,
                            items: const [
                              DropdownMenuItem(value: 'Todos', child: Text('Todos os Pneus')),
                              DropdownMenuItem(value: 'Em uso', child: Text('Em uso')),
                              DropdownMenuItem(value: 'Estoque', child: Text('Estoque')),
                              DropdownMenuItem(value: 'Reformado/Recapado', child: Text('Reformado/Recapado')),
                              DropdownMenuItem(value: 'Descartado', child: Text('Descartado')),
                            ],
                            onChanged: (novo) {
                              if (novo != null) setState(() => _filtroStatus = novo);
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Custo Total (Filtrado):',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'R\$ ${_custoTotalPneus.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: listaExibida.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum pneu encontrado com estes filtros.',
                            style: TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: listaExibida.length,
                          itemBuilder: (context, index) {
                            final pneu = listaExibida[index];
                            final kmInstalacao = int.tryParse(pneu['quilometragem_instalacao']?.toString() ?? '0') ?? 0;
                            final kmRodados = (kmAtualVeiculo > kmInstalacao) ? (kmAtualVeiculo - kmInstalacao) : 0;
                            final custo = double.tryParse(pneu['custo']?.toString() ?? '0') ?? 0.0;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: const Icon(Icons.radio_button_checked, color: Colors.white),
                                ),
                                title: Text(
                                  'Nº Fogo: ${pneu['numero_fogo'] ?? 'Sem número'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Posição: ${pneu['posicao'] ?? 'Não informada'}'),
                                    Text('Marca: ${pneu['marca'] ?? '-'} | Medida: ${pneu['medida'] ?? '-'}'),
                                    Text(
                                      'Rodados: ${kmRodados.toStringAsFixed(0)} km (Instalação: $kmInstalacao km)',
                                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                    ),
                                    Text('Status: ${pneu['status'] ?? 'Em uso'}', style: const TextStyle(fontStyle: FontStyle.italic)),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'R\$ ${custo.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                                  ],
                                ),
                                onTap: () async {
                                  final atualizado = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TelaCadastroPneu(
                                        veiculoId: widget.veiculo['id'],
                                        pneuExistente: pneu,
                                      ),
                                    ),
                                  );

                                  if (atualizado == true) {
                                    setState(() => _carregando = true);
                                    _carregarPneus();
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final adicionado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => TelaCadastroPneu(veiculoId: widget.veiculo['id']),
            ),
          );

          if (adicionado == true) {
            setState(() => _carregando = true);
            _carregarPneus();
          }
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Pneu'),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE CADASTRO / EDIÇÃO DE PNEU
// ----------------------------------------------------
class TelaCadastroPneu extends StatefulWidget {
  final int veiculoId;
  final Map<String, dynamic>? pneuExistente;

  const TelaCadastroPneu({super.key, required this.veiculoId, this.pneuExistente});

  @override
  State<TelaCadastroPneu> createState() => _TelaCadastroPneuState();
}

class _TelaCadastroPneuState extends State<TelaCadastroPneu> {
  final _formKey = GlobalKey<FormState>();
  final _numeroFogoController = TextEditingController();
  final _marcaController = TextEditingController();
  final _medidaController = TextEditingController();
  final _posicaoController = TextEditingController();
  final _kmInstalacaoController = TextEditingController();
  final _custoController = TextEditingController();
  final _dataInstalacaoController = TextEditingController();
  
  String _statusSelecionado = 'Em uso';
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    if (widget.pneuExistente != null) {
      final p = widget.pneuExistente!;
      _numeroFogoController.text = p['numero_fogo']?.toString() ?? '';
      _marcaController.text = p['marca']?.toString() ?? '';
      _medidaController.text = p['medida']?.toString() ?? '';
      _posicaoController.text = p['posicao']?.toString() ?? '';
      _kmInstalacaoController.text = p['quilometragem_instalacao']?.toString() ?? '';
      _custoController.text = p['custo']?.toString() ?? '';
      _dataInstalacaoController.text = p['data_instalacao']?.toString() ?? '';
      _statusSelecionado = p['status']?.toString() ?? 'Em uso';
    } else {
      // Sugere a data de hoje por predefinição
      final agora = DateTime.now();
      _dataInstalacaoController.text = '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';
    }
  }

  @override
  void dispose() {
    _numeroFogoController.dispose();
    _marcaController.dispose();
    _medidaController.dispose();
    _posicaoController.dispose();
    _kmInstalacaoController.dispose();
    _custoController.dispose();
    _dataInstalacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvarPneu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final dados = {
        'veiculo_id': widget.veiculoId,
        'numero_fogo': _numeroFogoController.text.trim(),
        'marca': _marcaController.text.trim(),
        'medida': _medidaController.text.trim(),
        'posicao': _posicaoController.text.trim(),
        'quilometragem_instalacao': int.tryParse(_kmInstalacaoController.text.trim()) ?? 0,
        'custo': double.tryParse(_custoController.text.trim().replaceAll(',', '.')) ?? 0.0,
        'status': _statusSelecionado,
        'data_instalacao': _dataInstalacaoController.text.trim(),
      };

      if (widget.pneuExistente == null) {
        await supabase.from('pneus').insert(dados);
      } else {
        await supabase.from('pneus').update(dados).eq('id', widget.pneuExistente!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _salvando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar pneu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final edicao = widget.pneuExistente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(edicao ? 'Editar Pneu' : 'Registar Novo Pneu'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _numeroFogoController,
                decoration: const InputDecoration(labelText: 'Número de Fogo / Série *'),
                validator: (v) => v == null || v.isEmpty ? 'Informe o número de identificação do pneu' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marcaController,
                      decoration: const InputDecoration(labelText: 'Marca (ex: Michelin, Firestone)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _medidaController,
                      decoration: const InputDecoration(labelText: 'Medida (ex: 295/80R22.5)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _posicaoController,
                decoration: const InputDecoration(labelText: 'Posição no Veículo (ex: Tração Externo Direito)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kmInstalacaoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'KM de Instalação *'),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o KM' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _custoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Custo (R\$)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataInstalacaoController,
                decoration: const InputDecoration(labelText: 'Data de Instalação (DD/MM/AAAA)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _statusSelecionado,
                decoration: const InputDecoration(labelText: 'Status do Pneu'),
                items: const [
                  DropdownMenuItem(value: 'Em uso', child: Text('Em uso')),
                  DropdownMenuItem(value: 'Estoque', child: Text('Estoque')),
                  DropdownMenuItem(value: 'Reformado/Recapado', child: Text('Reformado/Recapado')),
                  DropdownMenuItem(value: 'Descartado', child: Text('Descartado')),
                ],
                onChanged: (novo) {
                  if (novo != null) setState(() => _statusSelecionado = novo);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _salvando ? null : _salvarPneu,
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(edicao ? 'Atualizar Pneu' : 'Guardar Pneu', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TELA DE DASHBOARD FINANCEIRO E INDICADORES DA FROTA
// ----------------------------------------------------
class TelaDashboard extends StatefulWidget {
  final Map<String, dynamic>? veiculoEspecifico;

  const TelaDashboard({super.key, this.veiculoEspecifico});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  bool _carregando = true;
  double _totalFretes = 0.0;
  double _totalManutencoes = 0.0;
  double _totalCombustivel = 0.0;
  double _totalPneus = 0.0;
  int _totalVeiculos = 0;
  int _totalViagens = 0;

  List<Map<String, dynamic>> _listaVeiculos = [];
  String? _veiculoSelecionadoId;
  
  // Controle do Filtro de Mês (null = Todos os meses)
  int? _mesSelecionado;
  int _anoSelecionado = DateTime.now().year;

  final List<Map<String, dynamic>> _meses = [
    {'valor': 1, 'nome': 'Janeiro'},
    {'valor': 2, 'nome': 'Fevereiro'},
    {'valor': 3, 'nome': 'Março'},
    {'valor': 4, 'nome': 'Abril'},
    {'valor': 5, 'nome': 'Maio'},
    {'valor': 6, 'nome': 'Junho'},
    {'valor': 7, 'nome': 'Julho'},
    {'valor': 8, 'nome': 'Agosto'},
    {'valor': 9, 'nome': 'Setembro'},
    {'valor': 10, 'nome': 'Outubro'},
    {'valor': 11, 'nome': 'Novembro'},
    {'valor': 12, 'nome': 'Dezembro'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.veiculoEspecifico != null) {
      _veiculoSelecionadoId = widget.veiculoEspecifico!['id']?.toString();
    }
    _carregarListaVeiculosParaFiltro();
  }

  Future<void> _carregarListaVeiculosParaFiltro() async {
    try {
      final res = await supabase.from('veiculos').select('id, modelo, placa');
      setState(() {
        _listaVeiculos = List<Map<String, dynamic>>.from(res);
      });
    } catch (_) {}
    _carregarDadosDashboard();
  }

  // Função auxiliar para verificar se um registo está dentro do mês/ano selecionado
  bool _filtrarPorData(Map<String, dynamic> item) {
    if (_mesSelecionado == null) return true; // Se não escolheu mês, passa todos
    
    // Procura por campos comuns de data nas tabelas
    final dataStr = item['data'] ?? item['created_at'] ?? item['data_viagem'] ?? item['data_abastecimento'];
    if (dataStr == null) return false;

    final data = DateTime.tryParse(dataStr.toString());
    if (data == null) return false;

    return data.month == _mesSelecionado && data.year == _anoSelecionado;
  }

  Future<void> _carregarDadosDashboard() async {
    setState(() => _carregando = true);
    try {
      final veiculoIdLocal = _veiculoSelecionadoId;

      // 1. Veículos
      final resVeiculos = await supabase.from('veiculos').select('id');
      _totalVeiculos = (resVeiculos as List).length;

      // 2. Viagens e Fretes
      var queryViagens = supabase.from('viagens').select('frete_total, veiculo_id, data, created_at');
      if (veiculoIdLocal != null) {
        queryViagens = queryViagens.eq('veiculo_id', veiculoIdLocal as Object);
      }
      final resViagens = await queryViagens;
      
      final viagensFiltradas = (resViagens as List).where((v) => _filtrarPorData(v)).toList();
      _totalViagens = viagensFiltradas.length;
      _totalFretes = viagensFiltradas.fold(0.0, (soma, v) {
        final val = v['frete_total'];
        return soma + (val is num ? val.toDouble() : double.tryParse(val?.toString().replaceAll(',', '.') ?? '0') ?? 0.0);
      });

      // 3. Manutenções
      var queryManut = supabase.from('manutencoes').select('custo, veiculo_id, data, created_at');
      if (veiculoIdLocal != null) {
        queryManut = queryManut.eq('veiculo_id', veiculoIdLocal as Object);
      }
      final resManut = await queryManut;
      
      final manutFiltradas = (resManut as List).where((m) => _filtrarPorData(m)).toList();
      _totalManutencoes = manutFiltradas.fold(0.0, (soma, m) {
        final val = m['custo'];
        return soma + (val is num ? val.toDouble() : double.tryParse(val?.toString().replaceAll(',', '.') ?? '0') ?? 0.0);
      });

      // 4. Pneus
      var queryPneus = supabase.from('pneus').select('custo, veiculo_id, data, created_at');
      if (veiculoIdLocal != null) {
        queryPneus = queryPneus.eq('veiculo_id', veiculoIdLocal as Object);
      }
      final resPneus = await queryPneus;
      
      final pneusFiltrados = (resPneus as List).where((p) => _filtrarPorData(p)).toList();
      _totalPneus = pneusFiltrados.fold(0.0, (soma, p) {
        final val = p['custo'];
        return soma + (val is num ? val.toDouble() : double.tryParse(val?.toString().replaceAll(',', '.') ?? '0') ?? 0.0);
      });

      // 5. Combustível
      double totalComb = 0.0;
      try {
        var queryComb = supabase.from('combustivel').select();
        if (veiculoIdLocal != null) {
          queryComb = queryComb.eq('veiculo_id', veiculoIdLocal as Object);
        }
        final resComb = await queryComb;
        
        final combFiltrados = (resComb as List).where((c) {
          if (veiculoIdLocal != null) {
            final vIdRegisto = c['veiculo_id']?.toString() ?? c['id_veiculo']?.toString();
            if (vIdRegisto != null && vIdRegisto != veiculoIdLocal) return false;
          }
          return _filtrarPorData(c);
        }).toList();

        totalComb = combFiltrados.fold(0.0, (soma, c) {
          final val = c['valor_total'] ?? c['valor'] ?? c['custo'] ?? c['preco_total'] ?? c['total'];
          return soma + (val is num ? val.toDouble() : double.tryParse(val?.toString().replaceAll(',', '.') ?? '0') ?? 0.0);
        });
      } catch (_) {
        totalComb = 0.0;
      }
      _totalCombustivel = totalComb;

      setState(() {
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados do dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double custoTotal = _totalManutencoes + _totalPneus + _totalCombustivel;
    final double lucroLiquido = _totalFretes - custoTotal;

    String tituloAppBar = 'Dashboard Financeiro';
    if (_veiculoSelecionadoId != null && _listaVeiculos.isNotEmpty) {
      final vObj = _listaVeiculos.firstWhere(
        (v) => v['id'].toString() == _veiculoSelecionadoId,
        orElse: () => {},
      );
      if (vObj.isNotEmpty) {
        tituloAppBar = 'Dashboard: ${vObj['modelo']} (${vObj['placa']})';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloAppBar),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de Filtros (Veículo e Mês)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blueGrey.shade50,
            child: Column(
              children: [
                // Filtro de Veículo
                Row(
                  children: [
                    const Icon(Icons.directions_car, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _veiculoSelecionadoId,
                        hint: const Text('Todos os Veículos (Frota Completa)'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('🌐 Todos os Veículos (Geral)'),
                          ),
                          ..._listaVeiculos.map((v) {
                            return DropdownMenuItem<String>(
                              value: v['id'].toString(),
                              child: Text('${v['modelo'] ?? 'Veículo'} - ${v['placa'] ?? ''}'),
                            );
                          }),
                        ],
                        onChanged: (novoValor) {
                          setState(() => _veiculoSelecionadoId = novoValor);
                          _carregarDadosDashboard();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Filtro de Mês
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _mesSelecionado,
                        hint: const Text('Todos os Meses (Ano Inteiro)'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('📅 Todos os Meses (Geral)'),
                          ),
                          ..._meses.map((m) {
                            return DropdownMenuItem<int?>(
                              value: m['valor'] as int,
                              child: Text('${m['nome']} / $_anoSelecionado'),
                            );
                          }),
                        ],
                        onChanged: (novoMes) {
                          setState(() => _mesSelecionado = novoMes);
                          _carregarDadosDashboard();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carregarDadosDashboard,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _CardIndicador(
                                titulo: 'Faturamento',
                                valor: 'R\$ ${_totalFretes.toStringAsFixed(2)}',
                                cor: Colors.green,
                                icone: Icons.trending_up,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CardIndicador(
                                titulo: 'Custos Totais',
                                valor: 'R\$ ${custoTotal.toStringAsFixed(2)}',
                                cor: Colors.red,
                                icone: Icons.trending_down,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _CardIndicador(
                                titulo: 'Lucro Líquido',
                                valor: 'R\$ ${lucroLiquido.toStringAsFixed(2)}',
                                cor: lucroLiquido >= 0 ? Colors.indigo : Colors.red.shade900,
                                icone: Icons.account_balance_wallet,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CardIndicador(
                                titulo: 'Viagens Registadas',
                                valor: '$_totalViagens viagens',
                                cor: Colors.blue,
                                icone: Icons.local_shipping,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Distribuição de Custos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              height: 220,
                              child: custoTotal == 0
                                  ? const Center(child: Text('Sem custos registados para este período.'))
                                  : PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                        sections: [
                                          if (_totalCombustivel > 0)
                                            PieChartSectionData(
                                              color: Colors.orange,
                                              value: _totalCombustivel,
                                              title: 'Combustível',
                                              radius: 50,
                                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          if (_totalManutencoes > 0)
                                            PieChartSectionData(
                                              color: Colors.redAccent,
                                              value: _totalManutencoes,
                                              title: 'Manutenção',
                                              radius: 50,
                                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          if (_totalPneus > 0)
                                            PieChartSectionData(
                                              color: Colors.teal,
                                              value: _totalPneus,
                                              title: 'Pneus',
                                              radius: 50,
                                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Resumo Detalhado de Despesas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.build, color: Colors.redAccent),
                                title: const Text('Manutenções'),
                                trailing: Text('R\$ ${_totalManutencoes.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.radio_button_checked, color: Colors.teal),
                                title: const Text('Pneus'),
                                trailing: Text('R\$ ${_totalPneus.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.local_gas_station, color: Colors.orange),
                                title: const Text('Combustível'),
                                trailing: Text('R\$ ${_totalCombustivel.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CardIndicador extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData icone;

  const _CardIndicador({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                Icon(icone, color: cor, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cor),
            ),
          ],
        ),
      ),
    );
  }
}