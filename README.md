# VitaWallet API

Ruby on Rails API backend para VitaWallet.

- **Producción:** https://ch-vita-wallet-fe.vercel.app/
- **Frontend repo:** https://github.com/reynaldoqs/ch_vita_wallet_fe

## 1. Setup

### Requisitos previos

- Ruby 4.0.1
- PostgreSQL 17 (o Docker)
- Bundler

### Instalación local

```bash
# Clonar el repositorio
git clone <repo-url>
cd vitawallet_api

# Configurar variables de entorno
cp .env.example .env

# Instalar dependencias
bundle install

# Crear y migrar la base de datos
rails db:create db:migrate

# Cargar datos de prueba
rails db:seed

# Levantar el servidor
rails server
```

El servidor estará disponible en `http://localhost:3000`.


### Usuario de prueba

Después del seed se crea automáticamente:

- **Email:** `demo@vitawallet.io`
- **Password:** `password123`
- **Balances iniciales:** 1,000 USD | 500,000 CLP | 0.5 BTC | 100 USDC | 100 USDT

### Ejecutar tests

```bash
rails db:test:prepare
bundle exec rspec
```

## 2. Decisiones técnicas

### Arquitectura MVC

El proyecto sigue la arquitectura **Model-View-Controller** clásica de Rails, extendida con una capa de **Services** para encapsular lógica de negocio compleja:

```
app/
├── controllers/                    # (C) Reciben requests, delegan y responden
│   ├── application_controller.rb   #     Autenticación JWT global
│   └── api/v1/
│       ├── auth_controller.rb
│       ├── wallets_controller.rb
│       ├── prices_controller.rb
│       ├── exchanges_controller.rb
│       └── transactions_controller.rb
├── models/                         # (M) Representan datos + validaciones + relaciones
│   ├── user.rb
│   ├── wallet.rb
│   ├── balance.rb
│   └── transaction.rb
├── services/                       # Lógica de negocio fuera de controllers/models
│   ├── jwt_service.rb
│   ├── price_service.rb
│   └── exchange_service.rb
```

Al ser API-only no hay capa de vistas tradicional — los controllers retornan JSON directamente.

---

### Modelo de datos

Se crearon 4 tablas en PostgreSQL con las siguientes relaciones:

```
┌──────────────┐       ┌──────────────┐       ┌──────────────────┐
│    users     │       │   wallets    │       │    balances       │
├──────────────┤       ├──────────────┤       ├──────────────────┤
│ id (PK)      │──1:1──│ id (PK)      │──1:N──│ id (PK)          │
│ email (UNQ)  │       │ user_id (FK) │       │ wallet_id (FK)   │
│ password_dig │       │ created_at   │       │ currency (STR)   │
│ created_at   │       │ updated_at   │       │ amount (DEC 18,8)│
│ updated_at   │       └──────────────┘       │ created_at       │
└──────────────┘              │                │ updated_at       │
                              │                └──────────────────┘
                              │                UNQ: [wallet_id, currency]
                              │
                              │         ┌──────────────────────┐
                              │         │    transactions      │
                              └───1:N───├──────────────────────┤
                                        │ id (PK)              │
                                        │ wallet_id (FK)       │
                                        │ from_currency (STR)  │
                                        │ to_currency (STR)    │
                                        │ from_amount (DEC)    │
                                        │ to_amount (DEC)      │
                                        │ exchange_rate (DEC)  │
                                        │ status (STR) [IDX]   │
                                        │ created_at           │
                                        │ updated_at           │
                                        └──────────────────────┘
```


### Services

#### `JwtService`

Encapsula la generación y validación de tokens JWT para autenticación stateless.

```ruby
class JwtService
  SECRET = Rails.application.credentials.secret_key_base || ENV.fetch("SECRET_KEY_BASE")
  ALGORITHM = "HS256"
  EXPIRATION = (ENV.fetch("JWT_EXPIRATION_HOURS", "24").to_i).hours

  def self.encode(payload)
    payload[:exp] = EXPIRATION.from_now.to_i
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, algorithm: ALGORITHM)
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::DecodeError
    nil
  end
end
```

- Usa `secret_key_base` de Rails como secreto, algoritmo HS256
- Expiración configurable via `JWT_EXPIRATION_HOURS` (default 24h)
- `decode` retorna `nil` en caso de token inválido o expirado

#### `PriceService`

Consume la API externa de precios de VitaWallet y los cachea.

```ruby
def self.fetch_prices
  Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
    fetch_from_api
  end
rescue => e
  cached = Rails.cache.read(CACHE_KEY)
  raise ApiError, "Unable to fetch prices" unless cached
  cached
end
```

- **Cache** con `Rails.cache.fetch` y TTL de 30 segundos
- **Fallback**: si la API falla pero hay cache disponible, retorna el último valor
- **Timeouts**: 10s total, 5s de conexión
- Normaliza la respuesta de la API agrupando por crypto y fiat con precios `buy`/`sell`

#### `ExchangeService`

Núcleo de la lógica de negocio. Ejecuta intercambios fiat ↔ crypto de forma atómica.

```ruby
def execute
  validate!
  rate = fetch_rate
  to_amount = calculate_to_amount(rate)

  ActiveRecord::Base.transaction do
    tx = @wallet.transactions.create!(...)
    deduct_balance!
    credit_balance!(to_amount)
    tx.update!(status: "completed")
    tx
  end
end
```

1. **Valida par de monedas** — Solo permite fiat→crypto o crypto→fiat
2. **Valida monto** — Mayor a 0
3. **Valida saldo** — Verifica que haya fondos suficientes
4. **Obtiene tasa** — Usa `PriceService`, precio `buy` al comprar crypto, `sell` al vender
5. **Calcula monto destino** — Con `BigDecimal` para precisión financiera
6. **Transacción atómica en BD** — `lock` a nivel de fila en balances para prevenir race conditions

---

### Protección de rutas con JWT

Todas las rutas están protegidas por defecto. El `ApplicationController` tiene un `before_action` que intercepta cada request:

```ruby
class ApplicationController < ActionController::API
  before_action :authenticate_request

  private

  def authenticate_request
    token = request.headers["Authorization"]&.split(" ")&.last
    decoded = JwtService.decode(token)

    if decoded
      @current_user = User.find_by(id: decoded[:user_id])
    end

    render json: { message: "Unauthorized" }, status: :unauthorized unless @current_user
  end
end
```

1. Extrae el token del header `Authorization: Bearer <token>`
2. Lo decodifica con `JwtService`
3. Busca al usuario por `user_id` del payload
4. Si falla en cualquier paso, retorna `401 Unauthorized`

Solo `AuthController` salta esta protección con `skip_before_action` para registro y login.

---

### Rutas de la API

Todas bajo el prefijo `/api/v1`.

| Método | Endpoint | Auth | Controller#Action | Descripción |
|--------|----------|:----:|-------------------|-------------|
| POST | `/api/v1/auth/register` | No | `auth#register` | Registra un nuevo usuario, crea wallet con balances y retorna JWT |
| POST | `/api/v1/auth/login` | No | `auth#login` | Autentica credenciales y retorna JWT |
| GET | `/api/v1/wallet/balances` | Sí | `wallets#balances` | Retorna balances fiat y crypto del usuario agrupados |
| GET | `/api/v1/prices` | Sí | `prices#index` | Retorna precios crypto en tiempo real (cacheados 30s) |
| POST | `/api/v1/exchange` | Sí | `exchanges#create` | Ejecuta un intercambio fiat↔crypto |
| GET | `/api/v1/transactions` | Sí | `transactions#index` | Lista transacciones con filtro por status y paginación |

### Decisiones clave resumidas

| Decisión | Justificación |
|----------|---------------|
| JWT sin Devise | Simplicidad para API-only. Stateless, sin sesiones ni cookies. |
| Service objects | Controllers delgados, lógica de negocio encapsulada y testeable. |
| Cache de precios (30s) | Balance entre frescura de datos y reducción de carga a la API externa. |
| Kaminari | Paginación madura, se integra nativamente con Rails. |

---

## 3. Qué quedó pendiente

- **Mejorar el sistema de transacciones**: Actualmente solo soporta intercambios fiat→crypto y crypto→fiat. Falta extenderlo para soportar otros tipos de transacciones (fiat→fiat, crypto→crypto, depósitos, retiros, transferencias entre usuarios, etc.).
- Documentación Swagger con rswag
- CI/CD pipeline
