# Arquitetura do LEGIS

```text
Câmara dos Deputados
        │
        ▼
      ETL
 extract → transform → load
        │
        ▼
      MySQL
        │
        ▼
    FastAPI
        │
   ┌────┴────┐
   ▼         ▼
Insomnia  Frontend
```

## Responsabilidades

- `etl/`: acessa a fonte externa, normaliza os dados e executa carga idempotente;
- `database/`: mantém o esquema, índices e seed do banco;
- `backend/app/models/`: representa as tabelas usadas pela API;
- `backend/app/repositories/`: concentra consultas ao banco;
- `backend/app/services/`: aplica regras de apresentação e dispara o ETL;
- `backend/app/api/`: define os endpoints públicos;
- `backend/app/schemas/`: define os formatos de entrada e saída;
- `frontend/`: reservado para a interface do sistema.

A regra principal é que o cliente consulta a API local, e a API consulta o MySQL. Nenhuma tela deve acessar diretamente a Câmara.
