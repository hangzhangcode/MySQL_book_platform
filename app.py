import streamlit as st
import pymysql
import pandas as pd
import uuid

# ===========================
# 1. 配置页面与数据库连接
# ===========================
st.set_page_config(page_title="校园二手闲置平台", layout="wide")

# 初始化连接 (加了缓存，避免重复连接)
@st.cache_resource
def init_connection():
    return pymysql.connect(
        host="localhost",
        user="root",
        password="txb32247",  # 改成你的密码
        database="campus_db",
        cursorclass=pymysql.cursors.DictCursor
    )

conn = init_connection()

# ===========================
# 2. 侧边栏导航
# ===========================
st.sidebar.title("🎓 校园二手市场")
page = st.sidebar.radio("选择功能", ["🏠 首页 (商品浏览)", "➕ 发布闲置", "📊 数据看板 (SQL演示)"])

# ===========================
# 3. 页面1：首页 (商品浏览) - 【修复 create_time 不存在错误】
# ===========================
if page == "🏠 首页 (商品浏览)":
    st.header("🛒 全部闲置商品")

    # 【修复：改用 item_id 排序，不需要 create_time 字段】
    @st.cache_data(ttl=60)  # 缓存1分钟，避免频繁查库
    def get_available_items():
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM item_info WHERE stock > 0 ORDER BY item_id DESC")
        return cursor.fetchall()

    items = get_available_items()

    if not items:
        st.info("暂无在售商品，快去发布吧！")
    else:
        # 遍历商品列表
        for item in items:
            with st.container():
                col1, col2 = st.columns([3, 1])
                with col1:
                    st.subheader(item['item_name'])
                    st.caption(f"分类：{item['item_category']}")
                    st.write(f"价格：¥ {item['item_price']:.2f}")
                    st.write(f"描述：{item['item_desc']}")
                with col2:
                    # 生成唯一key，避免Streamlit组件冲突
                    unique_key = f"buy_{item['item_id']}_{uuid.uuid4().hex[:8]}"
                    
                    if st.button(f"立即购买 (ID:{item['item_id']})", key=unique_key):
                        try:
                            cursor = conn.cursor()

                            # 1. 先查商品信息（卖家、价格、库存）
                            cursor.execute("SELECT seller_id, item_price, stock FROM item_info WHERE item_id = %s", (item['item_id'],))
                            res = cursor.fetchone()

                            if not res:
                                st.error("❌ 商品不存在或已下架")
                                st.stop()

                            seller_id, item_price, stock = res

                            # 2. 库存判断（防超卖）
                            if stock <= 0:
                                st.error("❌ 商品已卖完！")
                                st.stop()

                            # 3. 插入订单
                            sql = """
                                INSERT INTO trade_order
                                (item_id, buyer_id, seller_id, order_amount, order_status)
                                VALUES (%s, %s, %s, %s, '待付款')
                            """
                            cursor.execute(sql, (item['item_id'], 2, seller_id, item_price))

                            # 4. 必须提交！
                            conn.commit()

                            # 成功提示
                            st.success(f"✅ 下单成功！订单已生成")
                            st.balloons()
                            st.rerun()

                        except Exception as e:
                            st.error(f"❌ 下单失败：{str(e)}")
                            print("真实错误：", e)

                st.markdown("---")

# ===========================
# 4. 页面2：发布闲置
# ===========================
elif page == "➕ 发布闲置":
    st.header("📦 发布新商品")

    with st.form("publish_form", clear_on_submit=True):
        item_name = st.text_input("商品名称")
        item_category = st.selectbox("分类", ("教材书籍", "电子产品", "生活用品", "运动器材", "其他"))
        item_price = st.number_input("价格 (元)", min_value=0.01, step=0.01)
        item_desc = st.text_area("商品描述")
        submitted = st.form_submit_button("发布商品")

        if submitted:
            try:
                cursor = conn.cursor()
                sql = """
                    INSERT INTO item_info (seller_id, item_name, item_category, item_price, item_desc, stock)
                    VALUES (%s, %s, %s, %s, %s, 1)
                """
                cursor.execute(sql, (1, item_name, item_category, item_price, item_desc))
                conn.commit()
                st.success("✅ 发布成功！")

                # 清除首页缓存
                get_available_items.clear()

            except Exception as e:
                st.error(f"❌ 发布失败: {e}")

# ===========================
# 5. 页面3：数据看板 (SQL演示)
# ===========================
elif page == "📊 数据看板 (SQL演示)":
    st.header("🔍 SQL功能演示区")

    # --------------------------
    # 功能1：调用存储过程
    # --------------------------
    st.markdown("---")
    st.subheader("1. 调用存储过程：查看月度热销榜")
    month_input = st.text_input("输入月份 (格式: YYYY-MM)", value="2026-03")

    if st.button("执行存储过程 sp_monthly_hot_items"):
        try:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.callproc('sp_monthly_hot_items', (month_input,))
            result = cursor.fetchall()

            if result:
                df_hot = pd.DataFrame(result)
                st.dataframe(df_hot, use_container_width=True)
                st.success("✅ 存储过程执行成功！")
            else:
                st.info("该月份暂无已完成的交易数据")
        except Exception as e:
            st.error(f"❌ 执行失败: {e}")

    # --------------------------
    # 功能2：原始数据查看
    # --------------------------
    st.markdown("---")
    st.subheader("2. 原始数据查看")

    table_name = st.selectbox("选择要查看的表", ("sys_user", "item_info", "trade_order", "credit_log", "item_review"))

    if st.button(f"查询 {table_name} 表"):
        try:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute(f"SELECT * FROM {table_name} LIMIT 100")  # 加LIMIT 100防流量爆炸
            rows = cursor.fetchall()

            if rows:
                df_table = pd.DataFrame(rows)
                st.dataframe(df_table, use_container_width=True)
                st.success(f"✅ 成功读取 {len(rows)} 条数据")
            else:
                st.info("该表目前为空")

        except Exception as e:
            st.error(f"❌ 查询失败: {e}")
            st.info("提示：请确保数据库连接正常，且表名存在。")