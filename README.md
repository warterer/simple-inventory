# MyWebApp - Simple Inventory Service

## Варіант індивідуального завдання
N = 20

**Розрахунки:**
* V2 = (20 % 2) + 1 = 1 -> Спосіб конфігурації: Аргументи командного рядка. База даних: MariaDB.
* V3 = (20 % 3) + 1 = 3 -> Тематика: Simple Inventory.
* V5 = (20 % 5) + 1 = 1 -> Порт застосунку: 8080.

## Документація по розробленому веб-застосунку
**Призначення застосунку:**
`mywebapp` - це простий сервіс для ведення обліку обладнання (Simple Inventory). Дозволяє переглядати список предметів, додавати нові записи та переглядати детальну інформацію про конкретний предмет.

**Середовище для розробки:**
* Node.js (v20+)
* MariaDB
* npm пакети: `express`, `mariadb`, `minimist`

**Як запустити локально:**
1. Клонувати репозиторій.
2. Виконати `npm install`.
3. Виконати міграцію: `node migrate.js --db_user=root --db_pass=root --db_name=inventory_db`
4. Запустити сервер: `node app.js --port=8080 --db_user=root --db_pass=root --db_name=inventory_db`

## Документація по API-ендпоінтах
Застосунок підтримує `text/html` або `application/json` для бізнес-логіки:
* `GET /` — Кореневий ендпоінт. Віддає лише `text/html` зі списком доступних API.
* `GET /items` — Виводить список усіх предметів в інвентарі (id, name).
* `POST /items` — Створює новий запис. Тіло запиту: `name`, `quantity`.
* `GET /items/<id>` — Виводить детальну інформацію по запису (id, name, quantity, created_at).
* `GET /health/alive` — Перевірка доступності сервісу (HTTP 200 OK).
* `GET /health/ready` — Перевірка підключення до БД (HTTP 200 OK або 500).

*health-ендпоінти доступні лише локально на ВМ і заблоковані ззовні через Nginx.*

## CI/CD Pipeline
 
Пайплайн складається з 4 джобів які виконуються послідовно:
 
```
lint + test → build-and-push → deploy
```
 
### Тригери
 
| Подія | lint | test | build-and-push | deploy |
|---|---|---|---|---|
| Push в `main` | ✅ | ✅ | ✅ | ❌ |
| Pull Request в `main` | ✅ | ✅ | ❌ | ❌ |
| Annotated tag `v*` | ✅ | ✅ | ✅ | ✅ |
 
### Джоби
 
**lint** — статичний аналіз коду:
- ESLint — аналіз JavaScript
- Hadolint — аналіз Dockerfile
- Yamllint — аналіз YAML файлів
**test** — автоматичні тести:
- Jest з покриттям коду (мінімум 40%)
- Артефакт зі звітом покриття завантажується для комітів в `main`
**build-and-push** — збірка Docker образу:
- Публікується в GitHub Container Registry (`ghcr.io`)
- Теги для коміту в `main`: `latest`, `sha-<full-commit-hash>`
- Теги для annotated tag: `stable`, `<tag>`
**deploy** — розгортання на self-hosted runner:
- Виконується тільки на annotated tags
- Пулить новий образ і перезапускає systemd сервіс
- Верифікує доступність сервісу та коректність налаштування Nginx
### Branch Protection Rules
 
Злиття в `main` заблоковано якщо не пройшли `lint` і `test`.
 
## Документація по розгортанню
 
### Вимоги до віртуальної машини
 
- OS: Ubuntu 22.04 Server
- CPU: 2 cores
- RAM: 2 GB
- Disk: 20 GB
- Docker встановлений
### Налаштування target node
 
```bash
git clone https://github.com/warterer/simple-inventory
cd simple-inventory
chmod +x setup-target.sh
./setup-target.sh
```
 
Після виконання скрипта відредагувати `/opt/mywebapp/.env`:
 
```env
DB_ROOT_PASSWORD=your_root_password
DB_NAME=inventory_db
DB_USER=app
DB_PASSWORD=your_app_password
GITHUB_REPOSITORY=warterer/simple-inventory
```
 
Запустити сервіс:
 
```bash
sudo systemctl start mywebapp.service
```
 
### Self-hosted Runner
 
Runner налаштований на окремій VM і підключений до репозиторію через GitHub Actions.
 
> **Важливо:** після завершення демонстрації VM з runner'ом зупиняється щоб унеможливити несанкціонований доступ.
 
### Управління доступом
 
| Користувач | Доступ | Права |
|---|---|---|
| `student` | SSH/Console | повні права sudo |
| `teacher` | SSH/Console | повні права sudo, пароль вимагає зміни |
| `operator` | SSH/Console | обмежені права sudo (тільки mywebapp та nginx) |