import os
import pandas as pd
from sqlalchemy import create_engine, text


class DataLoader:

    def __init__(self, config):
        self.views = getattr(config, 'VIEWS', {}) or {}
        self.db_uri = getattr(config, 'DB_URI', '')
        self.engine = None
        if self.db_uri:
            try:
                self.engine = create_engine(self.db_uri, connect_args={})
            except Exception:
                self.engine = None

    def get_dashboard_metrics(self):
        if not self.engine:
            return self._sample_metrics()
        
        try:
            sql = text("SELECT * FROM vw_DashboardMetrics")
            df = pd.read_sql(sql, self.engine)
            if df.empty:
                return self._sample_metrics()
            
            row = df.iloc[0]
            return {
                'total_customers': int(row.get('TotalCustomers', 0)),
                'total_stock_items': int(row.get('TotalStockItems', 0)),
                'total_delivery_methods': int(row.get('TotalDeliveryMethods', 0)),
                'total_sales_records': int(row.get('TotalSalesRecords', 0)),
                'grand_total_sales': float(row.get('GrandTotalSales', 0)),
                'average_sale_amount': float(row.get('AverageSaleAmount', 0)),
                'total_order_lines': int(row.get('TotalOrderLines', 0)),
                'total_quantity_sold': int(row.get('TotalQuantitySold', 0)),
                'total_tax_collected': float(row.get('TotalTaxCollected', 0)),
                'total_unique_dates': int(row.get('TotalUniqueDates', 0)),
            }
        except Exception as e:
            print(f"Error fetching dashboard metrics: {e}")
            return self._sample_metrics()

    def get_system_status(self):
        if not self.engine:
            return {'status': 'Sample Data', 'last_transaction': None, 'today_sales': 0, 'today_amount': 0}
        
        try:
            sql = text("SELECT * FROM vw_SystemStatus")
            df = pd.read_sql(sql, self.engine)
            if df.empty:
                return {'status': 'No Data', 'last_transaction': None, 'today_sales': 0, 'today_amount': 0}
            
            row = df.iloc[0]
            return {
                'status': row.get('SystemStatus', 'Unknown'),
                'last_transaction': row.get('LastTransactionDate'),
                'today_sales': int(row.get('TodaySalesCount', 0)),
                'today_amount': float(row.get('TodaySalesAmount', 0)),
            }
        except Exception as e:
            print(f"Error fetching system status: {e}")
            return {'status': 'Error', 'last_transaction': None, 'today_sales': 0, 'today_amount': 0}

    def get_additional_stats(self):
        if not self.engine:
            return self._sample_additional_stats()
        
        try:
            sql = text("SELECT * FROM vw_AdditionalStats")
            df = pd.read_sql(sql, self.engine)
            if df.empty:
                return self._sample_additional_stats()
            
            row = df.iloc[0]
            return {
                'top_customer_name': str(row.get('TopCustomerName', 'N/A')),
                'top_customer_sales': float(row.get('TopCustomerSales', 0)),
                'top_product_name': str(row.get('TopProductName', 'N/A')),
                'top_product_sales': float(row.get('TopProductSales', 0)),
                'most_used_delivery': str(row.get('MostUsedDeliveryMethod', 'N/A')),
                'delivery_usage_count': int(row.get('DeliveryMethodUsageCount', 0)),
            }
        except Exception as e:
            print(f"Error fetching additional stats: {e}")
            return self._sample_additional_stats()

    def get_all_charts(self):
        if self.views:
            return [{'name': k, 'title': v.get('title', k)} for k, v in self.views.items()]
        return [
            {'name': 'sample_sales', 'title': 'Sample Sales by Month'},
            {'name': 'sample_customers', 'title': 'Sample Orders by Customer'},
        ]

    def get_chart_data(self, name):
        if self.engine and name in self.views:
            try:
                view_name = self.views[name].get('view_name')
                sql = text(f"SELECT * FROM {view_name}")
                df = pd.read_sql(sql, self.engine)
                return self._df_to_chart(df)
            except Exception:
                return self._sample_data(name)

        return self._sample_data(name)

    def _df_to_chart(self, df: pd.DataFrame):
        if df.shape[1] >= 2:
            labels = df.iloc[:, 0].astype(str).tolist()
            try:
                values = pd.to_numeric(df.iloc[:, 1], errors='coerce').fillna(0).tolist()
            except Exception:
                values = df.iloc[:, 1].astype(str).tolist()
        else:
            labels = df.index.astype(str).tolist()
            values = pd.to_numeric(df.iloc[:, 0], errors='coerce').fillna(0).tolist()

        return {'labels': labels, 'values': values, 'type': 'bar'}

    def _sample_metrics(self):
        """Sample metrics when database is not available."""
        return {
            'total_customers': 0,
            'total_stock_items': 0,
            'total_delivery_methods': 0,
            'total_sales_records': 0,
            'grand_total_sales': 0,
            'average_sale_amount': 0,
            'total_order_lines': 0,
            'total_quantity_sold': 0,
            'total_tax_collected': 0,
            'total_unique_dates': 0,
        }

    def _sample_additional_stats(self):
        """Sample additional stats when database is not available."""
        return {
            'top_customer_name': 'N/A',
            'top_customer_sales': 0,
            'top_product_name': 'N/A',
            'top_product_sales': 0,
            'most_used_delivery': 'N/A',
            'delivery_usage_count': 0,
        }

    def _sample_data(self, name: str):
        if name == 'sample_customers':
            labels = ['Alice', 'Bob', 'Charlie', 'Diana']
            values = [23, 17, 35, 12]
            return {'labels': labels, 'values': values, 'type': 'pie'}

        labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
        values = [1200, 1500, 900, 1800, 2000, 1700]
        return {'labels': labels, 'values': values, 'type': 'bar'}
