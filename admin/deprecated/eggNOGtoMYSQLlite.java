import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.sql.*;

class eggNOGtoMYSQLlite {
    
    public static void main(String args[]) {
        
        try {
            
            // Open Files needed     
            FileInputStream fstream = new FileInputStream(args[0]);
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));

            String strLine;
            // Set Varibles needed for Parser  
            String BlastNameHolder = "";
            String DatabaseIndexHolder = "";
            int FoundSent = 0;
            String BlastMatchCheck = "";
            String HeapForPrint = "";
            int FoundIndex=0;
            int NotFoundIndex = 0;
            String BlastIndexCheck ="";
            String eggNOGIndexHolder = "";
            String UniprotMatchCheck = "";
            int ArrayInitialize2=0;
            String ParsedMascotHolder = "";
            int InCorrectCounter = 0;
            String ParsedMascotIndexCheck = "";
            int MatchFoundflag = 0;
            int MatchFoundCounter = 0;
            int NotFoundCounter = 0;
            String removecomment = "";
            String eggNOGdatabaseID = "";
            String eggNOGTempHolder = "";
            String eggNOGForCommit = "";
            
           //sqllite database initilization 
            Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            
            stat.executeUpdate("delete from eggNOGIndex");
            
            PreparedStatement prep = conn.prepareStatement("insert into eggNOGIndex values (?, ?);");
            
            conn.setAutoCommit(false);
            
            int i = 0;
            while ((strLine = br.readLine()) != null) {
                
                i++;

                if (i % 1000 == 0) {
                    System.err.print("\r[" + i + "]   ");
                
                    prep.executeBatch();
                }
                                           
                // for loop, cycles through entires, tokenezies, compares, commits 

               StringTokenizer st1 = new StringTokenizer(strLine);
               eggNOGdatabaseID = st1.nextToken();
               while (st1.hasMoreTokens()) {
                   eggNOGTempHolder=st1.nextToken();
                   eggNOGForCommit = eggNOGForCommit + " " + eggNOGTempHolder ;
               }

               prep.setString(1,eggNOGdatabaseID);
               prep.setString(2,eggNOGForCommit);
               prep.addBatch();	
               eggNOGForCommit= "";
               
           }
		

           prep.executeBatch();
           conn.setAutoCommit(true);
        
           
           /*
           if (ToPrint.equals(PrintSent))  {
               ResultSet rs = stat.executeQuery("select * from eggNOGIndex;");
               while (rs.next()) {
                   System.out.println("EggNogIndexValue = " + rs.getString("eggNOGIndexTerm"));
                   System.out.println("EggNogDefinition = " + rs.getString("eggNOGDescriptionValue"));
               }	
           }
		   */
           
           //Close the input stream
           in.close();
           conn.close();
           
           
       } 
       catch (Exception e){//Catch exception if any
           System.err.println("Error: " + e.getMessage());
       }
   }
}



