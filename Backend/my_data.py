import csv
import models
from database import SessionLocal

def append_test_data():
    db_session = SessionLocal()
    try:
        with open("MOCK_DATA.csv", mode="r", encoding="utf-8") as file:
            reader = csv.DictReader(file)

            for row in reader:
                print(f"Adding item: {row['name']}, {row['description']}")
                db_item = models.Item(
                    name=row["name"],
                    description=row["description"]
                )
                db_session.add(db_item)
            
            db_session.commit()
    finally:
        db_session.close()

if __name__ == "__main__":
    append_test_data()
    