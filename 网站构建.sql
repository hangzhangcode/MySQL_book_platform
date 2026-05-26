-- =============================================
-- 1. 创建数据库 (如果已存在请先删除)
-- =============================================
DROP DATABASE IF EXISTS campus_db;
CREATE DATABASE campus_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE campus_db;

-- =============================================
-- 2. 创建数据表
-- =============================================

-- 表1: 用户表 (sys_user)
CREATE TABLE sys_user (
    user_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
    student_id VARCHAR(20) NOT NULL UNIQUE COMMENT '学号（唯一认证）',
    user_name VARCHAR(50) NOT NULL COMMENT '昵称',
    phone VARCHAR(11) NOT NULL UNIQUE COMMENT '手机号',
    credit_score INT DEFAULT 100 NOT NULL COMMENT '信用分(0-100)',
    user_status ENUM('正常', '限制交易', '封禁') DEFAULT '正常' COMMENT '账户状态',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
    CONSTRAINT chk_credit_score CHECK (credit_score BETWEEN 0 AND 100)
) COMMENT '用户表';

-- 表2: 商品表 (item_info)
CREATE TABLE item_info (
    item_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '商品ID',
    seller_id INT NOT NULL COMMENT '卖家ID',
    item_name VARCHAR(100) NOT NULL COMMENT '商品名称',
    item_category ENUM('教材书籍', '电子产品', '生活用品', '运动器材', '其他') NOT NULL COMMENT '分类',
    item_desc TEXT COMMENT '商品描述',
    item_price DECIMAL(10,2) NOT NULL COMMENT '价格',
    item_status ENUM('在售', '已锁定', '已售出', '已下架') DEFAULT '在售' COMMENT '状态',
    stock INT DEFAULT 1 NOT NULL COMMENT '库存',
    publish_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '发布时间',
    FOREIGN KEY (seller_id) REFERENCES sys_user(user_id),
    CONSTRAINT chk_item_price CHECK (item_price > 0),
    CONSTRAINT chk_item_stock CHECK (stock >= 0)
) COMMENT '闲置商品表';

-- 表3: 交易订单表 (trade_order)
CREATE TABLE trade_order (
    order_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '订单ID',
    item_id INT NOT NULL COMMENT '商品ID',
    buyer_id INT NOT NULL COMMENT '买家ID',
    seller_id INT NOT NULL COMMENT '卖家ID',
    order_amount DECIMAL(10,2) NOT NULL COMMENT '订单金额',
    order_status ENUM('待付款', '待发货', '待收货', '已完成', '已取消', '退款中', '已退款') DEFAULT '待付款' COMMENT '订单状态',
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    pay_time DATETIME COMMENT '付款时间',
    confirm_time DATETIME COMMENT '确认收货时间',
    FOREIGN KEY (item_id) REFERENCES item_info(item_id),
    FOREIGN KEY (buyer_id) REFERENCES sys_user(user_id),
    FOREIGN KEY (seller_id) REFERENCES sys_user(user_id)
) COMMENT '交易订单表';

-- 表4: 信用分变动记录表 (credit_log)
CREATE TABLE credit_log (
    log_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '记录ID',
    user_id INT NOT NULL COMMENT '用户ID',
    change_value INT NOT NULL COMMENT '变动值(正/负)',
    change_reason VARCHAR(200) NOT NULL COMMENT '变动原因',
    change_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '变动时间',
    FOREIGN KEY (user_id) REFERENCES sys_user(user_id)
) COMMENT '信用分变动日志表';

-- 表5: 商品评价表 (item_review)
CREATE TABLE item_review (
    review_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '评价ID',
    order_id INT NOT NULL COMMENT '订单ID',
    user_id INT NOT NULL COMMENT '评价人ID',
    rating INT NOT NULL COMMENT '评分(1-5星)',
    comment TEXT COMMENT '评价内容',
    review_time DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '评价时间',
    FOREIGN KEY (order_id) REFERENCES trade_order(order_id),
    FOREIGN KEY (user_id) REFERENCES sys_user(user_id),
    CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 5)
) COMMENT '商品评价表';

-- =============================================
-- 3. 创建触发器 (Triggers)
-- =============================================

-- 触发器1: 订单生成时，自动锁定商品并扣减库存
DELIMITER //
CREATE TRIGGER trg_order_lock_item
AFTER INSERT ON trade_order
FOR EACH ROW
BEGIN
    -- 1. 扣减库存
    UPDATE item_info 
    SET stock = stock - 1
    WHERE item_id = NEW.item_id;
    
    -- 2. 将商品状态更新为“已锁定”
    UPDATE item_info 
    SET item_status = '已锁定'
    WHERE item_id = NEW.item_id;
    
    -- 3. 如果库存减到0，自动下架
    IF (SELECT stock FROM item_info WHERE item_id = NEW.item_id) <= 0 THEN
        UPDATE item_info SET item_status = '已下架' WHERE item_id = NEW.item_id;
    END IF;
END //
DELIMITER ;

-- 触发器2: 订单完成后，自动更新买卖双方信用分
DELIMITER //
CREATE TRIGGER trg_order_complete_credit
AFTER UPDATE ON trade_order
FOR EACH ROW
BEGIN
    -- 只有当状态从“待收货”变为“已完成”时触发
    IF OLD.order_status = '待收货' AND NEW.order_status = '已完成' THEN
        -- 给买家加2分
        UPDATE sys_user SET credit_score = LEAST(credit_score + 2, 100) WHERE user_id = NEW.buyer_id;
        INSERT INTO credit_log(user_id, change_value, change_reason) 
        VALUES (NEW.buyer_id, 2, '完成交易奖励');
        
        -- 给卖家加3分
        UPDATE sys_user SET credit_score = LEAST(credit_score + 3, 100) WHERE user_id = NEW.seller_id;
        INSERT INTO credit_log(user_id, change_value, change_reason) 
        VALUES (NEW.seller_id, 3, '成功出售商品奖励');
    END IF;
END //
DELIMITER ;

-- =============================================
-- 4. 创建存储过程 (Stored Procedures)
-- =============================================

-- 存储过程1: 生成月度热门商品排行榜
DELIMITER //
CREATE PROCEDURE sp_monthly_hot_items(IN p_month VARCHAR(7))
BEGIN
    SELECT 
        i.item_id,
        i.item_name,
        i.item_category,
        COUNT(o.order_id) AS sale_count,
        SUM(o.order_amount) AS total_revenue
    FROM item_info i
    LEFT JOIN trade_order o ON i.item_id = o.item_id 
        AND DATE_FORMAT(o.confirm_time, '%Y-%m') = p_month
        AND o.order_status = '已完成'
    GROUP BY i.item_id, i.item_name, i.item_category
    HAVING sale_count > 0
    ORDER BY sale_count DESC, total_revenue DESC
    LIMIT 10;
END //
DELIMITER ;

-- 存储过程2: 订单退款流程 (演示事务)
DELIMITER //
CREATE PROCEDURE sp_order_refund(IN p_order_id INT)
BEGIN
    DECLARE v_item_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT '退款失败，事务已回滚' AS result;
    END;
    
    -- 开启事务
    START TRANSACTION;
    
    -- 1. 获取订单对应的商品ID
    SELECT item_id INTO v_item_id FROM trade_order WHERE order_id = p_order_id;
    
    -- 2. 更新订单状态为“已退款”
    UPDATE trade_order 
    SET order_status = '已退款' 
    WHERE order_id = p_order_id;
    
    -- 3. 回滚商品库存，并重新上架
    UPDATE item_info 
    SET stock = stock + 1, item_status = '在售'
    WHERE item_id = v_item_id;
    
    -- 提交事务
    COMMIT;
    SELECT '退款成功' AS result;
END //
DELIMITER ;

-- =============================================
-- 5. 插入逼真的模拟数据
-- =============================================

-- 插入模拟用户 (10个学生)
INSERT INTO sys_user (student_id, user_name, phone, credit_score) VALUES
('2023010001', '张航', '13800138001', 100),
('2023010002', '李想', '13800138002', 98),
('2023010003', '王浩然', '13800138003', 100), -- 这里会被CHECK约束修正为100，演示用
('2023010004', '陈曦', '13800138004', 95),
('2023010005', '杨紫萱', '13800138005', 100),
('2023010006', '刘明辉', '13800138006', 88),
('2023010007', '赵雨晴', '13800138007', 100),
('2023010008', '孙宇轩', '13800138008', 92),
('2023010009', '周欣怡', '13800138009', 100),
('2023010010', '吴泽宇', '13800138010', 97);

-- 修正信用分(因为CHECK只是阻止插入，这里手动把超过100的改回来)
UPDATE sys_user SET credit_score = 100 WHERE credit_score > 100;

-- 插入模拟商品 (校园常见闲置)
INSERT INTO item_info (seller_id, item_name, item_category, item_desc, item_price, stock) VALUES
(1, '高等数学同济第七版（上下册）', '教材书籍', '九成新，有少量笔记，送练习册', 35.00, 1),
(2, '罗技K380无线蓝牙键盘', '电子产品', '粉色，使用半年，续航良好', 120.00, 1),
(3, '宜家台灯LED护眼灯', '生活用品', '白色，可调节亮度，带USB充电口', 45.00, 2),
(4, '尤尼克斯羽毛球拍（单拍）', '运动器材', '入门级，送3个球', 80.00, 1),
(5, 'C++ Primer Plus 第6版', '教材书籍', '全新未拆封，京东购入', 65.00, 1),
(1, '小米充电宝20000mAh', '电子产品', '大容量，可上飞机，有轻微划痕', 50.00, 1),
(6, '宿舍床头置物架', '生活用品', '免打孔，承重强，灰色', 15.00, 3),
(7, '斯伯丁篮球7号球', '运动器材', '手感好，送气筒气针', 90.00, 1),
(8, '新东方雅思词汇词根+联想', '教材书籍', '红宝书，有翻阅痕迹', 20.00, 1),
(9, '漫步者W820NB头戴式耳机', '电子产品', '主动降噪，使用一年，包装齐全', 280.00, 1);

-- 插入模拟历史订单 (让数据看起来更真实)
-- 注意：下面的INSERT会自动触发触发器 trg_order_lock_item
INSERT INTO trade_order (item_id, buyer_id, seller_id, order_amount, order_status, create_time, confirm_time) VALUES
(1, 2, 1, 35.00, '已完成', '2026-03-01 10:00:00', '2026-03-03 15:00:00'),
(3, 4, 3, 45.00, '已完成', '2026-03-05 12:00:00', '2026-03-06 18:00:00'),
(5, 1, 5, 65.00, '已完成', '2026-03-10 09:00:00', '2026-03-12 11:00:00'),
(7, 8, 6, 15.00, '已完成', '2026-03-15 14:00:00', '2026-03-16 10:00:00'),
(9, 10, 9, 280.00, '已完成', '2026-03-20 16:00:00', '2026-03-22 12:00:00');

-- 手动把刚才因触发器锁定的商品改回“已售出”
UPDATE item_info SET item_status = '已售出' WHERE item_id IN (1, 3, 5, 7, 9);

-- =============================================
-- 执行完成提示
-- =============================================
SELECT '✅ 数据库初始化完成！' AS Message;
SELECT '📊 提示：可以调用 CALL sp_monthly_hot_items(''2026-03''); 查看效果' AS Tip;