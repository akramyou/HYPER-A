# Mapping تقرير DAMMAM-3 06-10-2026.xlsx

تم فحص بنية ملف العينة المرفق. تحتوي الورقة على 7,125 صف بيانات، برؤوس الأعمدة التالية:

| Header | حقل التطبيق |
|---|---|
| `BRANCH_ID` | `branch_id` |
| `ORG_CODE` | `org_code` |
| `APPS_CODE` | `apps_code` |
| `POS_CODE` | `pos_code` |
| `DESCRIPTION` | `description_en` |
| `ARB_DESC` | `description_ar` |
| `UOM` | `uom` |
| `WH_STOCK` | `wh_stock` |
| `BR_STOCK` | `br_stock` |
| `SOLD_STK` | `sold_stk` |
| `WH_LOC_CODE` | `wh_loc_code` |
| `FLYER_ITEM` | `is_flyer` |

الأعمدة `SYS_CAL_QTY` و`MOD_QTY` غير مستوردة إلى حقول الكمية التشغيلية في هذا الإصدار؛ تحفظ كبيانات إضافية عند إنشاء صنف جديد، ما لم يقم المستخدم بتعيينها يدويًا. قيم المخزون السالبة لا تُصفّر تلقائيًا.

**قاعدة حماية البيانات:** إذا كان مفتاح `(apps_code, pos_code, branch_id)` موجودًا، تحدّث عملية الاستيراد حقول `wh_stock` و`br_stock` و`sold_stk` فقط. لا تغيّر الاسم أو وحدة القياس أو موقع التخزين أو بيانات الدفعات وتواريخها.
