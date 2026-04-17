FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/nginx.conf

# Copy our multi-domain nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy all HTML files into their per-domain folders
# Each domain gets its own subdirectory under /usr/share/nginx/html/

# Healthcare / Honor Health (Dee's portal)
RUN mkdir -p /usr/share/nginx/html/honorhealth
COPY honorhealth.tsmatter.html /usr/share/nginx/html/honorhealth/index.html

RUN mkdir -p /usr/share/nginx/html/healthcare
COPY honorhealth-dee.html /usr/share/nginx/html/healthcare/index.html

# HC domain portals
RUN mkdir -p /usr/share/nginx/html/hc-billing
COPY hc-billing.tsmatter.html /usr/share/nginx/html/hc-billing/index.html

RUN mkdir -p /usr/share/nginx/html/hc-compliance
COPY hc-compliance.tsmatter.html /usr/share/nginx/html/hc-compliance/index.html

RUN mkdir -p /usr/share/nginx/html/hc-grants
COPY hc-grants.tsmatter.html /usr/share/nginx/html/hc-grants/index.html

RUN mkdir -p /usr/share/nginx/html/hc-legal
COPY hc-legal.tsmatter.html /usr/share/nginx/html/hc-legal/index.html

RUN mkdir -p /usr/share/nginx/html/hc-medical
COPY hc-medical.tsmatter.html /usr/share/nginx/html/hc-medical/index.html

RUN mkdir -p /usr/share/nginx/html/hc-pharmacy
COPY hc-pharmacy.tsmatter.html /usr/share/nginx/html/hc-pharmacy/index.html

RUN mkdir -p /usr/share/nginx/html/hc-strategist
COPY hc-strategist.tsmatter.html /usr/share/nginx/html/hc-strategist/index.html

RUN mkdir -p /usr/share/nginx/html/hc-taxprep
COPY hc-taxprep.tsmatter.html /usr/share/nginx/html/hc-taxprep/index.html

RUN mkdir -p /usr/share/nginx/html/hc-vendors
COPY hc-vendors.tsmatter.html /usr/share/nginx/html/hc-vendors/index.html

RUN mkdir -p /usr/share/nginx/html/hc-financial
COPY hc-financial.tsmatter.html /usr/share/nginx/html/hc-financial/index.html

RUN mkdir -p /usr/share/nginx/html/hc-insurance
COPY hc-insurance.tsmatter.html /usr/share/nginx/html/hc-insurance/index.html

RUN mkdir -p /usr/share/nginx/html/hc-command
COPY hc-command.tsmatter.html /usr/share/nginx/html/hc-command/index.html

# Financial / command
RUN mkdir -p /usr/share/nginx/html/financial-command
COPY financial-command.tsmatter.html /usr/share/nginx/html/financial-command/index.html

# AZ
RUN mkdir -p /usr/share/nginx/html/az-ins
COPY az-ins.tsmatter.html /usr/share/nginx/html/az-ins/index.html

# Construction
RUN mkdir -p /usr/share/nginx/html/construction-command
COPY construction-command.tsmatter.html /usr/share/nginx/html/construction-command/index.html

# BPO
RUN mkdir -p /usr/share/nginx/html/bpo-legal
COPY bpo-legal.tsmatter.html /usr/share/nginx/html/bpo-legal/index.html

RUN mkdir -p /usr/share/nginx/html/bpo-realty
COPY bpo-realty.tsmatter.html /usr/share/nginx/html/bpo-realty/index.html

RUN mkdir -p /usr/share/nginx/html/bpo-tax
COPY bpo-tax.tsmatter.html /usr/share/nginx/html/bpo-tax/index.html

# Desert financial / REO
RUN mkdir -p /usr/share/nginx/html/desert-financial
COPY desert-financial.tsmatter.html /usr/share/nginx/html/desert-financial/index.html

RUN mkdir -p /usr/share/nginx/html/reo-pro
COPY reo-pro.tsmatter.html /usr/share/nginx/html/reo-pro/index.html

# Command portals
RUN mkdir -p /usr/share/nginx/html/pc-command
COPY pc-command.tsmatter.html /usr/share/nginx/html/pc-command/index.html

RUN mkdir -p /usr/share/nginx/html/rrd-command
COPY rrd-command.tsmatter.html /usr/share/nginx/html/rrd-command/index.html

RUN mkdir -p /usr/share/nginx/html/strategist
COPY strategist.tsmatter.html /usr/share/nginx/html/strategist/index.html

# Default fallback page
RUN mkdir -p /usr/share/nginx/html/default
COPY index.html /usr/share/nginx/html/default/index.html 2>/dev/null || \
  echo '<html><body style="background:#090E19;color:#F47C20;font-family:sans-serif;padding:40px"><h2>TSM · tsmatter.com</h2></body></html>' \
  > /usr/share/nginx/html/default/index.html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
