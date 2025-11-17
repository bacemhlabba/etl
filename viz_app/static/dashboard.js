// Professional Chart Color Schemes
const colorSchemes = {
  blue: {
    gradient: ['rgba(37, 99, 235, 0.85)', 'rgba(29, 78, 216, 0.95)'],
    border: 'rgba(37, 99, 235, 1)',
    background: 'rgba(37, 99, 235, 0.08)',
  },
  purple: {
    gradient: ['rgba(147, 51, 234, 0.85)', 'rgba(126, 34, 206, 0.95)'],
    border: 'rgba(147, 51, 234, 1)',
    background: 'rgba(147, 51, 234, 0.08)',
  },
  green: {
    gradient: ['rgba(22, 163, 74, 0.85)', 'rgba(21, 128, 61, 0.95)'],
    border: 'rgba(22, 163, 74, 1)',
    background: 'rgba(22, 163, 74, 0.08)',
  },
  orange: {
    gradient: ['rgba(234, 88, 12, 0.85)', 'rgba(194, 65, 12, 0.95)'],
    border: 'rgba(234, 88, 12, 1)',
    background: 'rgba(234, 88, 12, 0.08)',
  },
  pink: {
    gradient: ['rgba(219, 39, 119, 0.85)', 'rgba(190, 24, 93, 0.95)'],
    border: 'rgba(219, 39, 119, 1)',
    background: 'rgba(219, 39, 119, 0.08)',
  },
};

const chartTypes = {
  sales_by_customer: 'bar',
  sales_by_delivery: 'doughnut',
  top_stock_items: 'bar',
  sales_by_month: 'line',
  quantity_by_stock: 'bar',
};

async function fetchChartData(name) {
  const res = await fetch(`/api/chart/${name}`);
  if (!res.ok) throw new Error('Failed to fetch chart data');
  return await res.json();
}

function getColorScheme(index) {
  const schemes = Object.values(colorSchemes);
  return schemes[index % schemes.length];
}

function createGradient(ctx, colors) {
  const gradient = ctx.createLinearGradient(0, 0, 0, 400);
  gradient.addColorStop(0, colors[0]);
  gradient.addColorStop(1, colors[1]);
  return gradient;
}

function makeChart(ctx, data, title, index) {
  const chartType = chartTypes[data.name] || data.type || 'bar';
  const colorScheme = getColorScheme(index);
  
  let backgroundColor, borderColor;
  
  if (chartType === 'doughnut' || chartType === 'pie') {
    // Multi-color for pie/doughnut charts
    const schemes = Object.values(colorSchemes);
    backgroundColor = data.labels.map((_, i) => schemes[i % schemes.length].gradient[0]);
    borderColor = data.labels.map((_, i) => schemes[i % schemes.length].border);
  } else if (chartType === 'line') {
    // Gradient for line charts
    backgroundColor = createGradient(ctx, colorScheme.gradient);
    borderColor = colorScheme.border;
  } else {
    // Solid gradient for bar charts
    backgroundColor = createGradient(ctx, colorScheme.gradient);
    borderColor = colorScheme.border;
  }

  const config = {
    type: chartType,
    data: {
      labels: data.labels,
      datasets: [{
        label: title || '',
        data: data.values,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        borderWidth: 2,
        borderRadius: chartType === 'bar' ? 6 : 0,
        tension: 0.4,
        fill: chartType === 'line',
        pointBackgroundColor: chartType === 'line' ? colorScheme.border : undefined,
        pointBorderColor: '#fff',
        pointBorderWidth: 2,
        pointRadius: chartType === 'line' ? 5 : 0,
        pointHoverRadius: chartType === 'line' ? 7 : 0,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false,
      },
      plugins: {
        legend: {
          display: chartType === 'doughnut' || chartType === 'pie',
          position: 'bottom',
          labels: {
            padding: 16,
            font: {
              size: 12,
              family: "'Inter', sans-serif",
              weight: '500',
            },
            usePointStyle: true,
            pointStyle: 'circle',
            color: '#374151',
          }
        },
        tooltip: {
          backgroundColor: 'rgba(17, 24, 39, 0.96)',
          titleColor: '#f9fafb',
          bodyColor: '#e5e7eb',
          borderColor: 'rgba(75, 85, 99, 0.3)',
          borderWidth: 1,
          padding: 14,
          cornerRadius: 10,
          titleFont: {
            size: 14,
            weight: '600',
            family: "'Inter', sans-serif",
          },
          bodyFont: {
            size: 13,
            family: "'Inter', sans-serif",
          },
          callbacks: {
            label: function(context) {
              let label = context.dataset.label || '';
              if (label) {
                label += ': ';
              }
              if (context.parsed.y !== null) {
                label += new Intl.NumberFormat('en-US', {
                  style: 'decimal',
                  minimumFractionDigits: 0,
                  maximumFractionDigits: 2
                }).format(context.parsed.y);
              } else if (context.parsed !== null) {
                label += new Intl.NumberFormat('en-US', {
                  style: 'decimal',
                  minimumFractionDigits: 0,
                  maximumFractionDigits: 2
                }).format(context.parsed);
              }
              return label;
            }
          }
        }
      },
      scales: chartType !== 'doughnut' && chartType !== 'pie' ? {
        y: {
          beginAtZero: true,
          grid: {
            color: 'rgba(209, 213, 219, 0.3)',
            drawBorder: false,
            lineWidth: 1,
          },
          border: {
            display: false,
          },
          ticks: {
            font: {
              size: 11,
              family: "'Inter', sans-serif",
              weight: '500',
            },
            color: '#6b7280',
            padding: 8,
            callback: function(value) {
              return new Intl.NumberFormat('en-US', {
                notation: 'compact',
                compactDisplay: 'short'
              }).format(value);
            }
          }
        },
        x: {
          grid: {
            display: false,
            drawBorder: false,
          },
          border: {
            display: false,
          },
          ticks: {
            font: {
              size: 11,
              family: "'Inter', sans-serif",
              weight: '500',
            },
            color: '#6b7280',
            maxRotation: 45,
            minRotation: 0,
            padding: 6,
          }
        }
      } : {},
      animation: {
        duration: 1200,
        easing: 'easeInOutCubic',
      },
    }
  };
  
  return new Chart(ctx, config);
}

window.initDashboard = async function() {
  const canvases = document.querySelectorAll('canvas[id^="chart-"]');
  
  for (let i = 0; i < canvases.length; i++) {
    const canvas = canvases[i];
    const id = canvas.id.replace('chart-', '');
    const loadingEl = document.getElementById(`loading-${id}`);
    const timestampEl = document.getElementById(`timestamp-${id}`);
    
    try {
      // Show loading
      if (loadingEl) loadingEl.classList.remove('hidden');
      
      // Fetch data
      const data = await fetchChartData(id);
      data.name = id; // Store name for chart type detection
      
      // Hide loading
      if (loadingEl) loadingEl.classList.add('hidden');
      
      // Create chart
      const ctx = canvas.getContext('2d');
      makeChart(ctx, data, '', i);
      
      // Update timestamp
      if (timestampEl) {
        const now = new Date();
        timestampEl.textContent = `Updated: ${now.toLocaleTimeString()}`;
      }
    } catch (err) {
      console.error('Chart init error for', id, err);
      if (loadingEl) loadingEl.classList.add('hidden');
      
      // Show error state
      const container = canvas.closest('.relative');
      if (container) {
        container.innerHTML = `
          <div class="flex items-center justify-center h-full">
            <div class="text-center">
              <i class="fas fa-exclamation-triangle text-4xl text-red-400 mb-3"></i>
              <p class="text-red-600 font-medium">Failed to load chart</p>
              <p class="text-sm text-gray-500 mt-1">${err.message}</p>
            </div>
          </div>
        `;
      }
    }
  }
}

