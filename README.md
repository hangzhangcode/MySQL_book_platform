# MySQL Book Trading & Data Query Platform
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive second-hand book trading platform with robust MySQL-based data query capabilities, developed as a final project for the MySQL course. This platform enables users to browse, trade, and query second-hand books while demonstrating professional database design, optimization, and CRUD operation implementation.

## 📋 Project Overview
This project builds a full-featured second-hand book trading system centered on MySQL, covering core business scenarios such as:
- User registration, login, and profile management
- Book listing, search, and detail inquiry
- Trading order creation, payment status tracking, and history query
- Admin dashboard for data statistics and user/order management
- Advanced data query (filtering, sorting, aggregation, join queries)

### Key MySQL Features Demonstrated
- Relational schema design (ER diagram, table relationships)
- Index optimization for query performance
- Stored procedures/functions for business logic
- Triggers for data integrity
- Transaction management for safe trading operations
- View creation for simplified data access

## 🛠️ Tech Stack
- **Database**: MySQL 8.0+
- **Programming Language**: [Specify if used (e.g., Python/Java/PHP)]
- **Frontend** (optional): [Specify if used (e.g., HTML/CSS/JavaScript, Vue.js)]
- **Tools**: MySQL Workbench, Git, [other tools like DBeaver/Navicat]

## 📁 Database Schema
The core tables of the database include:

| Table Name       | Description                                  |
|------------------|----------------------------------------------|
| `users`          | Stores user account information (ID, name, email, password hash, etc.) |
| `books`          | Book metadata (ISBN, title, author, price, condition, seller ID, etc.) |
| `orders`         | Trading orders (order ID, buyer ID, book ID, order time, status, etc.) |
| `categories`     | Book category classification (fiction, non-fiction, textbook, etc.) |
| `order_status`   | Enumeration of order states (pending, paid, shipped, completed, cancelled) |

> Full ER diagram and schema SQL file are available in `/sql/schema.sql`

## 🚀 Quick Start

### Prerequisites
- Install MySQL 8.0 or higher
- Configure MySQL user with sufficient privileges (CREATE, INSERT, SELECT, UPDATE, DELETE)
- [Optional] Install [programming language runtime/environment]

### Installation
1. Clone the repository
   ```bash
   git clone https://github.com/hangzhangcode/MySQL_book_platform.git
   cd MySQL_book_platform
   ```

2. Import the database schema and sample data
   ```bash
   mysql -u [your_username] -p < sql/schema.sql
   mysql -u [your_username] -p < sql/sample_data.sql
   ```

3. [Optional] Run the application (if applicable)
   ```bash
   # Example for Python
   pip install -r requirements.txt
   python app.py
   ```

### Usage
#### Basic Queries Examples
1. Search books by title/author
   ```sql
   SELECT * FROM books 
   WHERE title LIKE '%MySQL%' OR author = 'Zhang San' 
   ORDER BY price ASC;
   ```

2. Query user's order history
   ```sql
   SELECT o.order_id, b.title, o.order_time, os.status_name
   FROM orders o
   JOIN books b ON o.book_id = b.book_id
   JOIN order_status os ON o.status_id = os.status_id
   WHERE o.buyer_id = 1001;
   ```

3. Statistics of monthly trading volume
   ```sql
   SELECT DATE_FORMAT(order_time, '%Y-%m') AS month, COUNT(*) AS order_count, SUM(b.price) AS total_amount
   FROM orders o
   JOIN books b ON o.book_id = b.book_id
   WHERE o.status_id = 4 -- Completed orders
   GROUP BY month
   ORDER BY month DESC;
   ```

## 📌 Project Structure
```
MySQL_book_platform/
├── sql/                  # SQL scripts
│   ├── schema.sql        # Database schema creation
│   ├── sample_data.sql   # Sample test data
│   ├── procedures.sql    # Stored procedures/functions
│   └── triggers.sql      # Database triggers
├── docs/                 # Project documentation (ER diagram, design notes)
├── src/                  # [Optional] Application source code
├── README.md             # Project README (this file)
└── LICENSE               # MIT License
```

## Dataset
The dataset is from Goodreads Book，you can get it on Kaggle. https://www.kaggle.com/datasets/pypiahmad/goodreads-book-reviews1

## 📝 Features to Extend
- Add user authentication with encrypted passwords (MD5/SHA256)
- Implement book inventory management
- Add review/ratings system for books/sellers
- Optimize query performance with composite indexes
- Integrate with a web frontend for better user experience

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Contact
If you have any questions or suggestions about the project, feel free to open an issue or contact the repository owner.

---
*This project is developed for educational purposes (MySQL course final project) and is not intended for production use.*
