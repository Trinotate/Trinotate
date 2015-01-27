import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.*;

class HMMDatabaseParse {

   public static void main(String args[]) {
      
       try {
           
           // Open Files needed and create the outfiles for each stratification  
           FileInputStream fstream = new FileInputStream(args[0]);
           DataInputStream in = new DataInputStream(fstream);
           BufferedReader br = new BufferedReader(new InputStreamReader(in));

           String strLine;
           int ArrayInitialize= 0;
           String TokenCheck = "";
           // Set Varibles needed for Parsing/Tokenization and Comparsion
           int LineCounter = 0;
           int PostArrayCounter = 0;
           String DatabaseTempHeap = "";
           String HMMERDbaseTokenHolder;
           String ACCtokencheck = "ACC";
           String GAtokencheck = "GA";
           String TCtokencheck = "TC";
           String NCtokencheck = "NC";
           String NameTokenCheck = "NAME";
           String LengthTokenCheck = "LENG";
           String DESCTokenCheck = "DESC";
           String DescriptionHolder = "";
           String NameForCommitt = "";
           String AccesionForCommitt = "";
           String DescriptionForCommitt = "";
           String GatherSequnceForCommitt= "";
           String GatherDomainForCommitt = "";
           String NoiseSequneceForCommitt= "";
           String NoiseDomianforCommitt= "";
           String TrustedSequneceforCommitt= "";
           String TrustedDomainforCommitt= "";
           String GatherSubStringForComitt = "";
           String TrustedSubStringForComitt = "";
           String NoiseSubStringForComitt = "";
           
           //sqllite database statmenet
           Class.forName("org.sqlite.JDBC");
           Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
           Statement stat = conn.createStatement();
           stat.executeUpdate("delete from PFAMreference;");

           PreparedStatement prep = conn.prepareStatement("insert into PFAMreference values (?, ?, ?, ?, ?, ?, ?, ?, ?)");
           

           int record_counter = 0;
                      
           while ((strLine = br.readLine()) != null)  {
               

               LineCounter++;
               if (LineCounter % 1000 == 0) {
                   System.err.print("\r[" + LineCounter + "]   ");
               }
               

               StringTokenizer st2 = new StringTokenizer(strLine);

               TokenCheck=st2.nextToken();
               if (TokenCheck.equals(NameTokenCheck)) {
                   TokenCheck=st2.nextToken();
                   NameForCommitt = TokenCheck;
               }
               else if (TokenCheck.equals(ACCtokencheck)) {
                   TokenCheck=st2.nextToken();
                   AccesionForCommitt = TokenCheck;
               }
               else if (TokenCheck.equals(DESCTokenCheck))	{
                   TokenCheck=st2.nextToken();
                   DescriptionForCommitt = TokenCheck;
               }
               else if (TokenCheck.equals(GAtokencheck))  {
                   TokenCheck=st2.nextToken();
                   GatherSequnceForCommitt= TokenCheck;
                   TokenCheck=st2.nextToken();
                   GatherSubStringForComitt =TokenCheck.substring(0, TokenCheck.length() - 1);
                   GatherDomainForCommitt = GatherSubStringForComitt;
               }
               else if (TokenCheck.equals(TCtokencheck))  {
                   TokenCheck=st2.nextToken();
                   TrustedSequneceforCommitt= TokenCheck;
                   TokenCheck=st2.nextToken();
                   TrustedSubStringForComitt =TokenCheck.substring(0, TokenCheck.length() - 1);
                   TrustedDomainforCommitt = TrustedSubStringForComitt;
               }
               else if (TokenCheck.equals(NCtokencheck))  {
                   TokenCheck=st2.nextToken();
                   NoiseSequneceForCommitt= TokenCheck;
                   TokenCheck=st2.nextToken();
                   NoiseSubStringForComitt =TokenCheck.substring(0, TokenCheck.length() - 1);
                   NoiseDomianforCommitt = NoiseSubStringForComitt;


                   // NC is last field we care about for this record.  Store it, and prepare for next record.

                   prep.setString(1,AccesionForCommitt);
                   prep.setString(2,NameForCommitt);
                   prep.setString(3,DescriptionForCommitt);
                   prep.setString(4,GatherSequnceForCommitt);
                   prep.setString(5,GatherDomainForCommitt);
                   prep.setString(6,TrustedSequneceforCommitt);
                   prep.setString(7,TrustedDomainforCommitt);
                   prep.setString(8,NoiseSequneceForCommitt);
                   prep.setString(9,NoiseDomianforCommitt);
                   prep.addBatch();	
                   
                  
                   NameForCommitt = "";
                   AccesionForCommitt = "";
                   DescriptionForCommitt = "";
                   GatherSequnceForCommitt= "";
                   GatherDomainForCommitt = "";
                   NoiseSequneceForCommitt= "";
                   NoiseDomianforCommitt= "";
                   TrustedSequneceforCommitt= "";
                   TrustedDomainforCommitt= "";
                   GatherSubStringForComitt = "";
                   TrustedSubStringForComitt = "";
                   NoiseSubStringForComitt = "";

                   record_counter++;

                   if (record_counter % 1000 == 0) {
                       prep.executeBatch();
                   }
                   
               }
               else {
                   int notneeded = 1;
               }
           }
           conn.setAutoCommit(false);
           prep.executeBatch();
           conn.setAutoCommit(true);
           

           
           in.close();


           /*
           if (ToPrint.equals(PrintSent)) {
               ResultSet rs = stat.executeQuery("select * from PFAMRefrenceDatabae;");
               while (rs.next()) {
                   System.out.println("PFAMIndexValue = " + rs.getString("pfam_accession"));
                   System.out.println("PFAMNameValue = " + rs.getString("pfam_domainname"));
                   System.out.println("PFAMDomainDescription = " + rs.getString("pfam_domaindescription"));
                   System.out.println("GatheringSequenceValue = " + rs.getString("Seqeunce_GatheringCutOff"));
                   System.out.println("GatheringDomainValue = " + rs.getString("Domain_GatheringCutOff"));
                   System.out.println("TrustedCutoffSequneceValue = " + rs.getString("Sequnece_TrustedCutOff"));
                   System.out.println("TrustedCutoffDomainValue = " + rs.getString("Domain_TrustedCutOff"));
                   System.out.println("NoiseCutoffSequenceValue = " + rs.getString("Sequnece_NoiseCutOff"));
                   System.out.println("NoiseCutoffDomainValue = " + rs.getString("Domain_NoiseCutOff"));
               }	
           }
           */
	 
           
	 
	 
           
           //Close the input stream
           in.close();
           
       } 
       catch (Exception e) { //Catch exception if any
           System.err.println("Error: " + e.getMessage());
       }
   }
}






