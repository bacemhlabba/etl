from flask import Flask, render_template, jsonify
import os
from data_loader import DataLoader
from config import Config

app = Flask(__name__, template_folder='templates', static_folder='static')

config = Config()
loader = DataLoader(config)


@app.route('/')
def index():
    charts = loader.get_all_charts()
    metrics = loader.get_dashboard_metrics()
    status = loader.get_system_status()
    additional_stats = loader.get_additional_stats()
    
    # All data comes from database - only pass through to template
    return render_template('index.html', 
                         charts=charts, 
                         metrics=metrics,
                         status=status,
                         additional_stats=additional_stats)


@app.route('/api/chart/<name>')
def chart_api(name):
    data = loader.get_chart_data(name)
    return jsonify(data)


if __name__ == '__main__':
    # Run from viz_app folder: python app.py
    app.run(debug=True)
