# Быстрый старт проекта 3web

## 📋 Настройки окружения

### Файл с переменными окружения

Настройки находятся в файле `backend/.local-env`:

```bash
backend/.local-env  # Основной файл настроек для локальной разработки
```

**Пример настроек** (уже создан `backend/.local-env.example`):

```env
DEBUG=True
SECRET_KEY=your-secret-key-here
STAGE=local
DATABASE_URL=postgres://postgres@db:5432/db
DOMAIN=localhost
SITE_NAME=3web Local Development
EMAIL_URL=console://
SECURE_SSL_REDIRECT=False
HTTP_PROTOCOL=http
```

### Основные переменные окружения:

| Переменная | Описание | Значение для разработки |
|------------|----------|------------------------|
| `DEBUG` | Режим отладки | `True` |
| `SECRET_KEY` | Секретный ключ Django | любая случайная строка |
| `STAGE` | Окружение (`local`/`test`/`live`) | `local` |
| `DATABASE_URL` | URL базы данных | `postgres://postgres@db:5432/db` |
| `DOMAIN` | Домен сайта | `localhost` |
| `EMAIL_URL` | Настройки email | `console://` (вывод в консоль) |
| `SECURE_SSL_REDIRECT` | Редирект на HTTPS | `False` |

---

## 🚀 Как запускать проект

### Вариант 1: Docker Compose (рекомендуется)

Самый простой способ - всё в контейнерах:

```bash
# 1. Создайте файл с настройками (если еще не создан)
cp backend/.local-env.example backend/.local-env

# 2. Отредактируйте backend/.local-env при необходимости

# 3. Запустите все сервисы
docker-compose up --build

# 4. В другом терминале выполните миграции (первый запуск)
docker-compose exec web python manage.py migrate

# 5. Создайте суперпользователя (опционально)
docker-compose exec web python manage.py createsuperuser

# 6. Откройте в браузере
# Frontend dev server: http://localhost:8090
# Django приложение: http://localhost:8000
# Django admin: http://localhost:8000/admin/
```

**Полезные команды:**

```bash
# Остановить все сервисы
docker-compose down

# Пересобрать образы
docker-compose build --no-cache

# Посмотреть логи
docker-compose logs -f web
docker-compose logs -f frontend

# Зайти в контейнер
docker-compose exec web bash

# Обновить requirements.txt
docker-compose run --rm web bash -c "cd backend && pip-compile requirements.in"

# Собрать статику
docker-compose exec web python manage.py collectstatic --noinput
```

---

### Вариант 2: Без Docker (только база в контейнере)

Если нужна максимальная производительность:

```bash
# 1. Запустите только базу данных
docker-compose up db

# 2. Создайте виртуальное окружение Python
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows

# 3. Установите Python зависимости
pip install -r backend/requirements.txt

# 4. Отредактируйте backend/.local-env
# Измените DATABASE_URL на: DATABASE_URL=postgres://postgres@localhost:5432/db

# 5. Раскомментируйте в backend/settings.py строку:
# environ.Env.read_env(os.path.join(BASE_DIR, '.local-env'))

# 6. Выполните миграции
python manage.py migrate

# 7. Запустите Django сервер
python manage.py runserver

# 8. В отдельном терминале запустите frontend
cd frontend
yarn install
yarn start

# 9. Откройте в браузере
# Frontend: http://localhost:8090
# Backend: http://localhost:8000
```

---

### Вариант 3: Production-подобное окружение локально

Для тестирования production настроек:

```bash
# 1. Измените backend/.local-env:
DEBUG=False
STAGE=live
DOMAIN=djangocms-template.0.0.0.0.nip.io
DEBUG_PROPAGATE_EXCEPTIONS=True

# 2. Соберите frontend
docker-compose run frontend yarn build

# 3. Соберите статику Django
docker-compose exec web python manage.py collectstatic --noinput --ignore node_modules

# 4. Перезапустите
docker-compose up web -d
```

---

## 📦 Установка зависимостей

### Python зависимости

```bash
# Обновить requirements.txt из requirements.in
pip-compile backend/requirements.in

# Установить зависимости
pip install -r backend/requirements.txt

# или в Docker
docker-compose run --rm web bash -c "cd backend && pip-compile requirements.in"
docker-compose build
```

### Node.js зависимости

```bash
cd frontend
yarn install

# или в Docker
docker-compose run --rm frontend yarn install
```

---

## 🗄️ Работа с базой данных

### Миграции

```bash
# Создать миграции
docker-compose exec web python manage.py makemigrations

# Применить миграции
docker-compose exec web python manage.py migrate

# Откатить миграцию
docker-compose exec web python manage.py migrate app_name migration_name
```

### Импорт/экспорт данных

```bash
# Создать дамп БД
docker-compose exec db pg_dump -U postgres db > dump.sql

# Восстановить из дампа
docker-compose exec -T db psql -U postgres db < dump.sql

# Сбросить базу полностью
docker-compose down
docker-compose rm db
docker volume rm 3web_postgres_data
docker-compose up db -d
docker-compose exec web python manage.py migrate
```

### Работа с Divio Cloud (опционально)

```bash
# Установить divio-cli
pip install divio-cli

# Авторизоваться
divio login

# Скачать БД с сервера
divio project pull db test

# Скачать медиа-файлы
divio project pull media test

# Залить БД на сервер
divio project push db test
```

---

## 🛠️ Разработка

### Django команды

```bash
# Shell
docker-compose exec web python manage.py shell

# Shell Plus (расширенный shell)
docker-compose exec web python manage.py shell_plus

# Создать суперпользователя
docker-compose exec web python manage.py createsuperuser

# Запустить тесты
docker-compose exec web python manage.py test

# Собрать статику
docker-compose exec web python manage.py collectstatic --noinput
```

### Frontend разработка

```bash
# Hot reload включен автоматически при docker-compose up

# Вручную запустить dev server
cd frontend
yarn start

# Собрать production версию
yarn build

# Отчет по бандлу
# Откройте: http://localhost:8090/webpack-dev-server
```

---

## 🐛 Отладка

### Логи

```bash
# Все логи
docker-compose logs -f

# Логи конкретного сервиса
docker-compose logs -f web
docker-compose logs -f frontend
docker-compose logs -f db
```

### Проблемы и решения

**Ошибка подключения к БД:**
```bash
# Проверьте, что БД запущена
docker-compose ps

# Перезапустите БД
docker-compose restart db
```

**Frontend не обновляется:**
```bash
# Очистите кеш и пересоберите
docker-compose down
docker-compose up --build frontend
```

**Статика не загружается:**
```bash
# Соберите статику заново
docker-compose exec web python manage.py collectstatic --noinput --clear
```

---

## 📚 Дополнительные ресурсы

- [Документация по локальной настройке](docs/local-setup-instructions.md)
- [Деплой на Divio](docs/deployment-divio.md)
- [Деплой на Heroku](docs/deployment-heroku.md)
- [Backend guidelines](docs/guidelines/backend.md)
- [Frontend guidelines](docs/guidelines/frontend.md)

---

## ✅ Чеклист первого запуска

- [ ] Создан файл `backend/.local-env`
- [ ] Установлен Docker и Docker Compose
- [ ] Выполнена команда `docker-compose up --build`
- [ ] Применены миграции `docker-compose exec web python manage.py migrate`
- [ ] Создан суперпользователь
- [ ] Открыт http://localhost:8000 в браузере
- [ ] Открыт http://localhost:8000/admin и выполнен вход
