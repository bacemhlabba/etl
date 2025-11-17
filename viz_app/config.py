
import os

class Config:
    def __init__(self):

        default_uri = 'mssql+pyodbc://MTS/WideWorldImporters_DWH?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes'
        self.DB_URI = os.getenv('DATABASE_URL', default_uri)

        self.VIEWS = {
            'sales_by_customer': {'view_name': 'vw_SalesByCustomer', 'title': 'Sales by Customer'},
            'sales_by_delivery': {'view_name': 'vw_SalesByDeliveryMethod', 'title': 'Sales by Delivery Method'},
            'top_stock_items': {'view_name': 'vw_TopStockItems', 'title': 'Top 10 Stock Items by Sales'},
            'sales_by_month': {'view_name': 'vw_SalesByMonth', 'title': 'Sales by Month'},
            'quantity_by_stock': {'view_name': 'vw_QuantityByStockItem', 'title': 'Top 15 Items by Quantity Sold'},
        }
