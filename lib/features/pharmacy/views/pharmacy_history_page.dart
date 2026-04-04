import 'package:flutter/material.dart';

import '../models/pharmacy_history.dart';

class PharmacyHistoryPage extends StatelessWidget {
  final List<PharmacyHistory> orderedPharmacies;
  final List<PharmacyHistory> searchedPharmacies;

  const PharmacyHistoryPage({
    Key? key,
    this.orderedPharmacies = const [],
    this.searchedPharmacies = const [],
  }) : super(key: key);

  Widget _header(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(50),
        bottomRight: Radius.circular(50),
      ),
      child: Container(
        height: 180,
        width: width,
        decoration: BoxDecoration(
          color: Color(0xFF5EABD6),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: 30,
              right: -100,
              child: _circularContainer(300, Color(0xFF5EABD6).withOpacity(0.3)),
            ),
            Positioned(
              top: -100,
              left: -45,
              child: _circularContainer(width * .5, Color(0xFF5EABD6).withOpacity(0.5)),
            ),
            Positioned(
              top: -180,
              right: -30,
              child: _circularContainer(
                width * .7,
                Colors.transparent,
                borderColor: Colors.white38,
              ),
            ),
            Positioned(
              top: 50,
              left: 0,
              child: Container(
                width: width,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "سجل الصيدليات",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      "نشاطك في الصيدليات",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularContainer(double height, Color color,
      {Color borderColor = Colors.transparent, double borderWidth = 2}) {
    return Container(
      height: height,
      width: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          _chip("${title.contains("طلبت") ? orderedPharmacies.length : searchedPharmacies.length} عنصر", color),
        ],
      ),
    );
  }

  Widget _chip(String text, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(15)),
        color: textColor.withAlpha(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _pharmacyCard(PharmacyHistory pharmacy, bool isOrdered) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 8,
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOrdered ? Color(0xFF5EABD6) : Colors.orange,
            ),
            child: Icon(
              isOrdered ? Icons.shopping_cart : Icons.search,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  pharmacy.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  pharmacy.address,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    SizedBox(width: 5),
                    Text(
                      pharmacy.date,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    Spacer(),
                    if (isOrdered)
                      _chip("تم الطلب", Color(0xFF5EABD6))
                    else
                      _chip("تم البحث", Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _header(context),
            SizedBox(height: 20),

            // Ordered Pharmacies Section
            if (orderedPharmacies.isNotEmpty) ...[
              _sectionHeader(
                "طلبات حديثة",
                "الصيدليات التي طلبت منها",
                Color(0xFF5EABD6),
              ),
              ...orderedPharmacies.map((pharmacy) =>
                  _pharmacyCard(pharmacy, true)
              ).toList(),
              SizedBox(height: 20),
            ],

            // Searched Pharmacies Section
            if (searchedPharmacies.isNotEmpty) ...[
              _sectionHeader(
                "بحث متكرر",
                "الصيدليات التي تبحث عنها غالباً",
                Colors.orange,
              ),
              ...searchedPharmacies.map((pharmacy) =>
                  _pharmacyCard(pharmacy, false)
              ).toList(),
            ],

            // Empty State
            if (orderedPharmacies.isEmpty && searchedPharmacies.isEmpty)
              Container(
                margin: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.history,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "لا يوجد سجل للصيدليات بعد",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "ستظهر هنا الصيدليات التي طلبت منها وبحثت عنها",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

