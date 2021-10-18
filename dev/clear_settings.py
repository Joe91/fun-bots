import sqlite3
import os
from os import walk

removeList = ["FB_Config_Trace", "FB_Settings"] #"FB_Permissions"

connection = sqlite3.connect("./../mod.db")
cursor = connection.cursor()

for removeTable in removeList:
    tablename = removeTable
    print("remove " + tablename)
    cursor.execute('DROP TABLE IF EXISTS '+ tablename)
        
connection.commit()
